import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/local_storage_service.dart';

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) => ProductNotifier(ref));
final categoryProvider = StateNotifierProvider<CategoryNotifier, CategoryState>((ref) => CategoryNotifier(ref));

class ProductState {
  final List<Product> products;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? searchQuery;
  final String? selectedCategory;
  final String sortBy;
  final bool inStockOnly;
  final String? error;
  final DateTime? lastSyncTime;

  ProductState({
    this.products = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.searchQuery,
    this.selectedCategory,
    this.sortBy = 'newest',
    this.inStockOnly = false,
    this.error,
    this.lastSyncTime,
  });

  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? searchQuery,
    String? selectedCategory,
    String? sortBy,
    bool? inStockOnly,
    String? error,
    DateTime? lastSyncTime,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery,
      selectedCategory: selectedCategory,
      sortBy: sortBy ?? this.sortBy,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      error: error,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  List<Product> get filteredProducts {
    var filtered = products;
    if (inStockOnly) filtered = filtered.where((p) => p.stockQuantity > 0).toList();
    switch (sortBy) {
      case 'price_asc': filtered.sort((a, b) => a.unitPrice.compareTo(b.unitPrice)); break;
      case 'price_desc': filtered.sort((a, b) => b.unitPrice.compareTo(a.unitPrice)); break;
      case 'name_asc': filtered.sort((a, b) => a.name.compareTo(b.name)); break;
      default: filtered.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    }
    return filtered;
  }
}

class ProductNotifier extends StateNotifier<ProductState> {
  final Ref ref;
  static const int _pageSize = 20;

  ProductNotifier(this.ref) : super(ProductState()) {
    _init();
  }

  Future<void> _init() async {
    final lastSync = await LocalStorageService.getLastSyncTime();
    print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(lastSyncTime: lastSync);
  }

  Future<void> loadProducts({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(apiServiceProvider);
      final newPage = refresh ? 1 : state.currentPage + 1;

      final newProducts = await api.fetchProducts(
        page: newPage,
        pageSize: _pageSize,
        search: state.searchQuery,
        category: state.selectedCategory,
      );

      final allProducts = refresh ? newProducts : [...state.products, ...newProducts];

      if (refresh && newPage == 1) {
        await LocalStorageService.saveProducts(allProducts);
      }

      print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(
        products: allProducts,
        isLoading: false,
        hasMore: newProducts.length == _pageSize,
        currentPage: newPage,
        lastSyncTime: refresh ? DateTime.now() : state.lastSyncTime,
        error: null,
      );
    } catch (e) {
      final localProducts = await LocalStorageService.getProducts();
      if (localProducts.isNotEmpty) {
        print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(
          products: localProducts,
          isLoading: false,
          hasMore: false,
          error: null,
        );
      } else {
        print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(
          isLoading: false,
          error: 'فشل الاتصال بالسيرفر: $e',
        );
      }
    }
  }

  Future<void> smartSync() async {
    final api = ref.read(apiServiceProvider);
    final localMeta = state.products.map((p) => {
      'sku': p.sku,
      'last_updated': p.lastUpdated.toIso8601String(),
    }).toList();

    final result = await api.syncProducts(localMeta);
    final updated = (result['updated'] as List).map((e) => Product.fromJson(e)).toList();
    final deletedSkus = result['deleted'] as List<String>;

    var newProducts = state.products.where((p) => !deletedSkus.contains(p.sku)).toList();
    for (var updatedProduct in updated) {
      final index = newProducts.indexWhere((p) => p.sku == updatedProduct.sku);
      if (index >= 0) {
        newProducts[index] = updatedProduct;
      } else {
        newProducts.add(updatedProduct);
      }
    }

    print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(
      products: newProducts,
      lastSyncTime: DateTime.now(),
    );
    await LocalStorageService.saveProducts(newProducts);
  }

  void setSearchQuery(String query) {
    print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(searchQuery: query.isEmpty ? null : query, hasMore: true, currentPage: 0);
    loadProducts(refresh: true);
  }

  void setCategory(String? category) {
    print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(selectedCategory: category, hasMore: true, currentPage: 0);
    loadProducts(refresh: true);
  }

  void setSortBy(String sortBy) => print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(sortBy: sortBy);
  void setInStockOnly(bool value) => print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(inStockOnly: value);
  
  Future<void> refresh() async {
    print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(hasMore: true, currentPage: 0, error: null);
    await loadProducts(refresh: true);
  }
}

class CategoryState {
  final List<String> categories;
  final bool isLoading;
  CategoryState({this.categories = const [], this.isLoading = false});
  CategoryState copyWith({List<String>? categories, bool? isLoading}) =>
      CategoryState(categories: categories ?? this.categories, isLoading: isLoading ?? this.isLoading);
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  final Ref ref;
  CategoryNotifier(this.ref) : super(CategoryState());

  Future<void> loadCategories() async {
    print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiServiceProvider);
      final categories = await api.fetchCategories();
      print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      print('✅ عدد المنتجات المستلمة: ${newProducts.length}'); state = state.copyWith(isLoading: false);
    }
  }
}
