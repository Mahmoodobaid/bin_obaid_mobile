// product_provider.dart
// مزود حالة المنتجات - نسخة احترافية نهائية
// يدعم: تحميل تدريجي (Pagination)، مزامنة مع الخادم، بحث ذكي،
// تصفية، فرز، وضع عدم الاتصال، تخزين Hive، وإدارة الأخطاء.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../models/product_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/sync_service.dart';
import '../../../../services/search_service.dart';
import '../../../../services/local_storage_service.dart';

// -------------------------------------------
// 1. مزود الخدمات الأساسية
// -------------------------------------------
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final syncServiceProvider = Provider<SyncService>((ref) {
  final box = Hive.box<Product>('products');
  return SyncService(ref.read(apiServiceProvider).supabase, box);
});
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.read(apiServiceProvider));
});

// -------------------------------------------
// 2. مزود حالة المنتجات الرئيسي
// -------------------------------------------
final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier(ref);
});

// -------------------------------------------
// 3. حالة المنتجات
// -------------------------------------------
class ProductState {
  final List<Product> items;           // المنتجات المعروضة حالياً (بعد Pagination والبحث والتصفية)
  final List<Product> allProducts;     // جميع المنتجات المحلية (للتخزين المؤقت)
  final bool isLoading;                // تحميل أولي أو Pagination
  final bool isSyncing;                // جاري المزامنة
  final double syncProgress;           // تقدم المزامنة (0-1)
  final String? syncError;             // خطأ المزامنة
  final DateTime? lastSyncTime;        // آخر مزامنة ناجحة
  final bool hasMore;                  // هل توجد صفحات أخرى للتحميل
  final int currentPage;               // الصفحة الحالية (لـ Pagination)
  final String? searchQuery;           // نص البحث الحالي
  final String? selectedCategory;      // التصنيف المختار
  final String sortBy;                 // ترتيب: 'newest', 'price_asc', 'price_desc', 'name_asc'
  final bool inStockOnly;              // عرض المتوفر فقط
  final String? error;                 // خطأ عام

  ProductState({
    this.items = const [],
    this.allProducts = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.syncProgress = 0.0,
    this.syncError,
    this.lastSyncTime,
    this.hasMore = true,
    this.currentPage = 0,
    this.searchQuery,
    this.selectedCategory,
    this.sortBy = 'newest',
    this.inStockOnly = false,
    this.error,
  });

  ProductState copyWith({
    List<Product>? items,
    List<Product>? allProducts,
    bool? isLoading,
    bool? isSyncing,
    double? syncProgress,
    String? syncError,
    DateTime? lastSyncTime,
    bool? hasMore,
    int? currentPage,
    String? searchQuery,
    String? selectedCategory,
    String? sortBy,
    bool? inStockOnly,
    String? error,
  }) {
    return ProductState(
      items: items ?? this.items,
      allProducts: allProducts ?? this.allProducts,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      syncError: syncError ?? this.syncError,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery,
      selectedCategory: selectedCategory,
      sortBy: sortBy ?? this.sortBy,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      error: error,
    );
  }

  // قائمة المنتجات بعد تطبيق التصفية والفرز (تُستخدم في UI)
  List<Product> get filteredItems {
    var filtered = List<Product>.from(items);
    if (inStockOnly) {
      filtered = filtered.where((p) => p.stockQuantity > 0).toList();
    }
    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      filtered = filtered.where((p) => p.category == selectedCategory).toList();
    }
    switch (sortBy) {
      case 'price_asc':
        filtered.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
        break;
      case 'price_desc':
        filtered.sort((a, b) => b.unitPrice.compareTo(a.unitPrice));
        break;
      case 'name_asc':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      default: // 'newest'
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return filtered;
  }

  bool get isEmpty => items.isEmpty && !isLoading;
  bool get isNotEmpty => items.isNotEmpty;
}

// -------------------------------------------
// 4. الـ Notifier
// -------------------------------------------
class ProductNotifier extends StateNotifier<ProductState> {
  final Ref _ref;
  static const int _pageSize = 20;
  late final Box<Product> _productBox;
  late final SyncService _syncService;
  late final SearchService _searchService;
  Timer? _searchDebounce;
  bool _isInitialized = false;

  ProductNotifier(this._ref) : super(ProductState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      _productBox = await Hive.openBox<Product>('products');
      _syncService = _ref.read(syncServiceProvider);
      _searchService = _ref.read(searchServiceProvider);

      // تحميل آخر وقت مزامنة من التخزين المحلي
      final lastSync = await LocalStorageService.getLastSyncTime();
      state = state.copyWith(lastSyncTime: lastSync);

      // تحميل جميع المنتجات من Hive (offline-first)
      final allLocalProducts = _productBox.values.toList();
      if (allLocalProducts.isNotEmpty) {
        state = state.copyWith(allProducts: allLocalProducts);
        await _loadInitialPage(); // تحميل الصفحة الأولى من Hive
      }

      // بدء مزامنة تلقائية في الخلفية (إذا مر وقت طويل أو أول مرة)
      _startBackgroundSync();

      _isInitialized = true;
    } catch (e) {
      state = state.copyWith(error: 'فشل التهيئة: $e');
    }
  }

  // تحميل الصفحة الأولى من Hive (دون انتظار الإنترنت)
  Future<void> _loadInitialPage() async {
    if (state.allProducts.isEmpty) return;
    final firstPage = state.allProducts.take(_pageSize).toList();
    state = state.copyWith(
      items: firstPage,
      currentPage: 1,
      hasMore: state.allProducts.length > _pageSize,
    );
  }

  // مزامنة في الخلفية (غير مزعجة)
  Future<void> _startBackgroundSync() async {
    await Future.delayed(const Duration(seconds: 2));
    final now = DateTime.now();
    final lastSync = state.lastSyncTime;
    if (lastSync == null || now.difference(lastSync).inMinutes > 30) {
      await syncWithServer(forceFull: lastSync == null);
    }
  }

  // -----------------------------------------
  // Pagination: تحميل المزيد من Hive
  // -----------------------------------------
  Future<void> loadMore({bool reset = false}) async {
    if (reset) {
      state = state.copyWith(
        isLoading: true,
        currentPage: 0,
        items: [],
        hasMore: true,
        error: null,
      );
      await _loadInitialPage();
      state = state.copyWith(isLoading: false);
      return;
    }

    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);
    final start = state.currentPage * _pageSize;
    final end = (start + _pageSize) > state.allProducts.length
        ? state.allProducts.length
        : start + _pageSize;

    if (start >= state.allProducts.length) {
      state = state.copyWith(hasMore: false, isLoading: false);
      return;
    }

    final newItems = state.allProducts.sublist(start, end);
    final updatedItems = [...state.items, ...newItems];
    state = state.copyWith(
      items: updatedItems,
      currentPage: state.currentPage + 1,
      hasMore: end < state.allProducts.length,
      isLoading: false,
    );
  }

  // -----------------------------------------
  // مزامنة مع الخادم (Delta أو Full)
  // -----------------------------------------
  Future<void> syncWithServer({bool forceFull = false}) async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, syncProgress: 0.05, syncError: null);

    SyncResult result;
    if (forceFull || state.lastSyncTime == null) {
      result = await _syncService.fullSync();
    } else {
      result = await _syncService.syncDelta(state.lastSyncTime);
    }

    if (result.success) {
      // تحديث المنتجات المحلية من Hive
      final allProducts = _productBox.values.toList();
      final firstPage = allProducts.take(_pageSize).toList();
      state = state.copyWith(
        allProducts: allProducts,
        items: firstPage,
        currentPage: 1,
        hasMore: allProducts.length > _pageSize,
        isSyncing: false,
        syncProgress: 1.0,
        lastSyncTime: DateTime.now(),
        syncError: null,
      );
      await LocalStorageService.saveLastSyncTime(DateTime.now());
      // إعادة تعيين شريط التقدم بعد ثانية
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) state = state.copyWith(syncProgress: 0.0);
      });
    } else {
      state = state.copyWith(
        isSyncing: false,
        syncError: result.error,
      );
    }
  }

  // -----------------------------------------
  // البحث الذكي (مع Debounce)
  // -----------------------------------------
  void smartSearch(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    state = state.copyWith(searchQuery: query, isLoading: true);
    final delay = query.length < 3 ? 500 : 200;
    _searchDebounce = Timer(Duration(milliseconds: delay), () async {
      if (query.trim().isEmpty) {
        // إعادة تعيين البحث
        await loadMore(reset: true);
        state = state.copyWith(isLoading: false);
        return;
      }
      final results = await _searchService.search(query, limit: _pageSize);
      state = state.copyWith(
        items: results,
        allProducts: results, // مؤقتاً للعرض
        hasMore: false,
        isLoading: false,
      );
    });
  }

  // -----------------------------------------
  // فلترة وفرز
  // -----------------------------------------
  void setCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
    _applyFiltersAndSort();
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
    _applyFiltersAndSort();
  }

  void setInStockOnly(bool value) {
    state = state.copyWith(inStockOnly: value);
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    // إعادة تطبيق الفلترة والفرز على جميع المنتجات
    final filtered = _applyFilters(state.allProducts);
    final sorted = _applySort(filtered);
    // Pagination على النتيجة الجديدة
    final firstPage = sorted.take(_pageSize).toList();
    state = state.copyWith(
      items: firstPage,
      allProducts: sorted,
      currentPage: 1,
      hasMore: sorted.length > _pageSize,
    );
  }

  List<Product> _applyFilters(List<Product> products) {
    var filtered = List<Product>.from(products);
    if (state.inStockOnly) {
      filtered = filtered.where((p) => p.stockQuantity > 0).toList();
    }
    if (state.selectedCategory != null && state.selectedCategory!.isNotEmpty) {
      filtered = filtered.where((p) => p.category == state.selectedCategory).toList();
    }
    return filtered;
  }

  List<Product> _applySort(List<Product> products) {
    final sorted = List<Product>.from(products);
    switch (state.sortBy) {
      case 'price_asc':
        sorted.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
        break;
      case 'price_desc':
        sorted.sort((a, b) => b.unitPrice.compareTo(a.unitPrice));
        break;
      case 'name_asc':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      default: // newest
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return sorted;
  }

  // تحديث يدوي (سحب للأسفل)
  Future<void> refresh() async {
    await syncWithServer(forceFull: false);
    await loadMore(reset: true);
  }

  // -----------------------------------------
  // إدارة المنتجات الفردية (للاستخدام في أماكن أخرى)
  // -----------------------------------------
  Product? getProductBySku(String sku) {
    return _productBox.get(sku);
  }

  Future<void> updateProduct(Product product) async {
    await _productBox.put(product.sku, product);
    // تحديث القوائم المحلية
    final allProducts = _productBox.values.toList();
    final firstPage = allProducts.take(_pageSize).toList();
    state = state.copyWith(
      allProducts: allProducts,
      items: firstPage,
    );
    _applyFiltersAndSort();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

// -------------------------------------------
// 5. مزود حالة التصنيفات (منفصل)
// -------------------------------------------
final categoryProvider = StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  return CategoryNotifier(ref);
});

class CategoryState {
  final List<String> categories;
  final bool isLoading;
  final String? error;
  CategoryState({this.categories = const [], this.isLoading = false, this.error});
  CategoryState copyWith({List<String>? categories, bool? isLoading, String? error}) =>
      CategoryState(
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  final Ref _ref;
  CategoryNotifier(this._ref) : super(CategoryState());

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = _ref.read(apiServiceProvider);
      final categories = await api.fetchCategories();
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}