import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/local_storage_service.dart';

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) => ProductNotifier(ref));

class ProductState {
  final List<Product> products;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? search;
  final String? category;
  ProductState({this.products = const [], this.isLoading = false, this.hasMore = true, this.page = 0, this.search, this.category});
  ProductState copyWith({List<Product>? products, bool? isLoading, bool? hasMore, int? page, String? search, String? category}) => ProductState(
      products: products ?? this.products, isLoading: isLoading ?? this.isLoading, hasMore: hasMore ?? this.hasMore, page: page ?? this.page, search: search, category: category);
  List<Product> get filteredProducts {
    var filtered = products;
    if (category != null) filtered = filtered.where((p) => p.category == category).toList();
    if (search != null && search!.isNotEmpty) filtered = filtered.where((p) => p.name.contains(search!) || p.sku.contains(search!)).toList();
    return filtered;
  }
}

class ProductNotifier extends StateNotifier<ProductState> {
  final Ref ref;
  static const int _pageSize = 20;

  ProductNotifier(this.ref) : super(ProductState());

  Future<void> loadProducts({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiServiceProvider);
      final newPage = refresh ? 1 : state.page + 1;
      final newProds = await api.fetchProducts(page: newPage, pageSize: _pageSize, search: state.search, category: state.category);
      final all = refresh ? newProds : [...state.products, ...newProds];
      if (refresh) await LocalStorageService.saveProducts(all);
      state = state.copyWith(products: all, isLoading: false, hasMore: newProds.length == _pageSize, page: newPage);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setSearch(String q) {
    state = state.copyWith(search: q.isEmpty ? null : q, page: 0, hasMore: true);
    loadProducts(refresh: true);
  }

  void setCategory(String? c) {
    state = state.copyWith(category: c, page: 0, hasMore: true);
    loadProducts(refresh: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(page: 0, hasMore: true);
    await loadProducts(refresh: true);
  }
}
