import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/shimmer_product_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../services/api_service.dart';

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

  Future<void> _diagnoseApi() async {
    final api = ref.read(apiServiceProvider);
    try {
      final products = await api.fetchProducts(page: 1, pageSize: 5);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تشخيص API'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عدد المنتجات المستلمة: ${products.length}'),
                const SizedBox(height: 12),
                if (products.isNotEmpty)
                  ...products.map((p) => Text('• ${p.sku}: ${p.name}')).toList()
                else
                  const Text('لم يتم استلام أي منتجات.'),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('خطأ في API'),
          content: Text('$e'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final categoryState = ref.watch(categoryProvider);
    final products = state.filteredProducts;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        title: const Text('كتالوج المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _diagnoseApi,
            tooltip: 'تشخيص API',
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: Column(
        children: [
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
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              EmptyState(
                                icon: Icons.inventory_2_outlined,
                                message: state.products.isEmpty ? 'لا توجد منتجات متاحة' : 'عدد المنتجات: ${state.products.length}',
                                actionLabel: 'تحديث',
                                onAction: () => ref.read(productProvider.notifier).refresh(),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _diagnoseApi,
                                icon: const Icon(Icons.bug_report),
                                label: const Text('تشخيص API'),
                              ),
                            ],
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
