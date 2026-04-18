import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/shimmer_product_card.dart';
import '../../../../core/widgets/empty_state.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});
  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts(refresh: true);
      ref.read(categoryProvider.notifier).loadCategories();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(productProvider.notifier).loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final categoryState = ref.watch(categoryProvider);
    final products = state.filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('كتالوج المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(productProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => ref.read(productProvider.notifier).setSearchQuery(value),
            ),
          ),
          // قائمة الفئات
          if (!categoryState.isLoading)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: categoryState.categories.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: const Text('الكل'),
                        selected: state.selectedCategory == null,
                        onSelected: (_) => ref.read(productProvider.notifier).setCategory(null),
                      ),
                    );
                  }
                  final cat = categoryState.categories[i - 1];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(cat),
                      selected: state.selectedCategory == cat,
                      onSelected: (_) => ref.read(productProvider.notifier).setCategory(cat),
                    ),
                  );
                },
              ),
            ),
          // شبكة المنتجات
          Expanded(
            child: state.isLoading && products.isEmpty
                ? GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75),
                    itemCount: 6,
                    itemBuilder: (_, __) => const ShimmerProductCard(),
                  )
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(state.error!, textAlign: TextAlign.center),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.read(productProvider.notifier).refresh(),
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : products.isEmpty
                        ? EmptyState(
                            icon: Icons.inventory_2_outlined,
                            message: 'لا توجد منتجات متاحة',
                            actionLabel: 'تحديث',
                            onAction: () => ref.read(productProvider.notifier).refresh(),
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref.read(productProvider.notifier).refresh(),
                            child: GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75),
                              itemCount: products.length + (state.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == products.length) {
                                  return const ShimmerProductCard();
                                }
                                return ProductCard(product: products[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
