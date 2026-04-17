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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(productProvider.notifier).loadProducts(refresh: true));
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(productProvider.notifier).loadProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final products = state.filteredProducts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('كتالوج المنتجات'),
        actions: [
          IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => context.push('/cart')),
        ],
      ),
      body: state.isLoading && products.isEmpty
          ? GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75),
              itemCount: 6,
              itemBuilder: (_, __) => const ShimmerProductCard(),
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
                    itemBuilder: (c, i) {
                      if (i == products.length) return const ShimmerProductCard();
                      return ProductCard(product: products[i]);
                    },
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
