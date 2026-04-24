import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../../../../models/product_model.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});
  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadMore(reset: true);
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        ref.read(productProvider.notifier).loadMore();
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: query.length < 3 ? 500 : 200), () {
      ref.read(productProvider.notifier).smartSearch(query);
    });
  }

  Future<void> _handleSync() async {
    HapticFeedback.mediumImpact();
    await ref.read(productProvider.notifier).syncWithServer(forceFull: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(productProvider.select((s) => s.items));
    final isSyncing = ref.watch(productProvider.select((s) => s.isSyncing));
    final isLoading = ref.watch(productProvider.select((s) => s.isLoading));
    final lastSync = ref.watch(productProvider.select((s) => s.lastSyncTime));
    final currentQuery = ref.watch(productProvider.select((s) => s.currentQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('كتالوج المنتجات'),
        actions: [
          IconButton(
            icon: RotationTransition(turns: isSyncing ? _rotationController : const AlwaysStoppedAnimation(0), child: const Icon(Icons.sync)),
            onPressed: isSyncing ? null : _handleSync,
          ),
          IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => context.push('/cart')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _onSearchChanged(''); }) : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (lastSync != null) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('${items.length} صنف | آخر مزامنة: ${DateFormat('HH:mm').format(lastSync!)}'),
          ),
          Expanded(
            child: isLoading && items.isEmpty
                ? GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                    itemCount: 6,
                    itemBuilder: (_, __) => Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  )
                : items.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey), const SizedBox(height: 16), Text(currentQuery.isEmpty ? 'لا توجد منتجات' : 'لا توجد نتائج'), if (currentQuery.isNotEmpty) TextButton(onPressed: () { _searchController.clear(); _onSearchChanged(''); }, child: const Text('مسح البحث'))]))
                    : RefreshIndicator(
                        onRefresh: () async => ref.read(productProvider.notifier).loadMore(reset: true),
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                          itemCount: items.length + (ref.read(productProvider).hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == items.length) return const Center(child: CircularProgressIndicator());
                            return ProductCard(product: items[index]);
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
    _scrollController.dispose(); _searchController.dispose(); _debounce?.cancel(); _rotationController.dispose();
    super.dispose();
  }
}
