import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../models/product_model.dart';
import '../../../../services/sync_service.dart';
import '../../../../services/search_service.dart';
import '../../../../services/api_service.dart';

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier(ref);
});

class ProductState {
  final List<Product> items;
  final List<Product> allProducts;
  final bool isLoading;
  final bool isSyncing;
  final double syncProgress;
  final String? syncError;
  final DateTime? lastSyncTime;
  final bool hasMore;
  final int page;
  final String currentQuery;

  ProductState({
    this.items = const [],
    this.allProducts = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.syncProgress = 0.0,
    this.syncError,
    this.lastSyncTime,
    this.hasMore = true,
    this.page = 0,
    this.currentQuery = '',
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
    int? page,
    String? currentQuery,
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
      page: page ?? this.page,
      currentQuery: currentQuery ?? this.currentQuery,
    );
  }
}

class ProductNotifier extends StateNotifier<ProductState> {
  final Ref ref;
  static const int _pageSize = 20;
  late Box<Product> _box;
  SyncService? _syncService;
  List<Product>? _cachedSearchResults;
  String _cachedQuery = '';

  ProductNotifier(this.ref) : super(ProductState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<Product>('products');
    _syncService = SyncService(ref.read(apiServiceProvider), _box);
    await loadMore(reset: true);
    _startBackgroundSync();
  }

  Future<void> loadMore({bool reset = false}) async {
    if (reset) {
      state = state.copyWith(isLoading: true, page: 0, items: [], hasMore: true);
    }
    if (!state.hasMore) return;
    final start = state.page * _pageSize;
    final allKeys = _box.keys.toList();
    if (start >= allKeys.length) {
      state = state.copyWith(hasMore: false, isLoading: false);
      return;
    }
    final end = (start + _pageSize) > allKeys.length ? allKeys.length : start + _pageSize;
    final newProducts = <Product>[];
    for (int i = start; i < end; i++) {
      final product = _box.get(allKeys[i]);
      if (product != null) newProducts.add(product);
    }
    final updatedItems = reset ? newProducts : [...state.items, ...newProducts];
    state = state.copyWith(
      items: updatedItems,
      page: reset ? 1 : state.page + 1,
      isLoading: false,
      hasMore: end < allKeys.length,
    );
    if (state.allProducts.isEmpty) {
      state = state.copyWith(allProducts: _box.values.toList());
    }
    _applySearchFilter();
  }

  void smartSearch(String query) {
    if (query == state.currentQuery) return;
    state = state.copyWith(currentQuery: query);
    _applySearchFilter();
  }

  void _applySearchFilter() {
    if (state.currentQuery.isEmpty) {
      state = state.copyWith(items: state.allProducts.take(_pageSize * (state.page+1)).toList());
      return;
    }
    if (_cachedQuery == state.currentQuery && _cachedSearchResults != null) {
      state = state.copyWith(items: _cachedSearchResults!);
      return;
    }
    _cachedQuery = state.currentQuery;
    final results = SearchService.searchInBox(_box, state.currentQuery);
    _cachedSearchResults = results;
    state = state.copyWith(items: results);
  }

  Future<void> syncWithServer({bool forceFull = false}) async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, syncProgress: 0.05);
    SyncResult result;
    if (forceFull || state.lastSyncTime == null) {
      result = await _syncService!.fullSync();
    } else {
      result = await _syncService!.syncDelta(state.lastSyncTime);
    }
    if (result.success) {
      await loadMore(reset: true);
      state = state.copyWith(isSyncing: false, syncProgress: 1.0, lastSyncTime: DateTime.now());
      Future.delayed(const Duration(seconds: 1), () {
        state = state.copyWith(syncProgress: 0.0);
      });
    } else {
      state = state.copyWith(isSyncing: false, syncError: result.error);
    }
  }

  void _startBackgroundSync() async {
    await Future.delayed(const Duration(seconds: 3));
    if (state.lastSyncTime == null || DateTime.now().difference(state.lastSyncTime!).inMinutes > 30) {
      await syncWithServer(forceFull: state.lastSyncTime == null);
    }
  }
}
