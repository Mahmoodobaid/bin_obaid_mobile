import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../providers/product_provider.dart';
import '../../../../widgets/product_card.dart';
import '../../../../widgets/shimmer_product_card.dart';
import '../../../../widgets/empty_state.dart';

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
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadMore(reset: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(productProvider.notifier).loadMore();
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final delay = query.length < 3 ? 500 : 200;
    _debounce = Timer(Duration(milliseconds: delay), () {
      ref.read(productProvider.notifier).smartSearch(query);
    });
  }

  Future<void> _handleManualSync() async {
    HapticFeedback.mediumImpact();
    await ref.read(productProvider.notifier).syncWithServer(forceFull: false);
    if (mounted && ref.read(productProvider).syncError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(productProvider).syncError!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت المزامنة بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(productProvider.select((s) => s.items));
    final isSyncing = ref.watch(productProvider.select((s) => s.isSyncing));
    final syncProgress = ref.watch(productProvider.select((s) => s.syncProgress));
    final isLoading = ref.watch(productProvider.select((s) => s.isLoading));
    final lastSync = ref.watch(productProvider.select((s) => s.lastSyncTime));
    final currentQuery = ref.watch(productProvider.select((s) => s.currentQuery));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isSyncing, syncProgress, isDark),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSearchBar(isDark),
                  _buildStatsRow(items.length, lastSync, isSyncing),
                ],
              ),
            ),
            _buildProductGrid(items, isLoading, currentQuery),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/invoice'),
          backgroundColor: const Color(0xFFF59E0B),
          icon: const Icon(Icons.receipt_long, color: Colors.white),
          label: const Text('فاتورة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool syncing, double progress, bool isDark) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 120,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        title: const Text('أصناف بن عبيد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade800, isDark ? const Color(0xFF1E293B) : Colors.blue.shade900],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: RotationTransition(
            turns: syncing ? _rotationController : const AlwaysStoppedAnimation(0),
            child: const Icon(Icons.sync_rounded, color: Colors.white),
          ),
          onPressed: syncing ? null : _handleManualSync,
          tooltip: 'مزامنة',
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              onPressed: () => context.push('/cart'),
              tooltip: 'السلة',
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: const Text('!', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
      bottom: syncing || progress > 0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(value: progress, color: Colors.orange, backgroundColor: Colors.transparent),
            )
          : null,
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Hero(
        tag: 'search_bar',
        child: Material(
          elevation: 5,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(15),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: '🔍 ابحث باسم القطعة، SKU، الباركود...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search_outlined, color: Colors.blue),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: () { _searchController.clear(); _onSearchChanged(''); })
                  : const Icon(Icons.qr_code_scanner_outlined, color: Colors.grey),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(int count, DateTime? lastSync, bool syncing) {
    final lastSyncStr = lastSync != null ? DateFormat('HH:mm').format(lastSync) : 'لم يتم';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$count صنف", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.sync_rounded, size: 12, color: syncing ? Colors.orange : Colors.blue),
                const SizedBox(width: 4),
                Text("آخر مزامنة: $lastSyncStr", style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> items, bool isLoading, String query) {
    if (isLoading && items.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.72),
          delegate: SliverChildBuilderDelegate((context, index) => const ShimmerProductCard(), childCount: 6),
        ),
      );
    }

    if (items.isEmpty) {
      return SliverFillRemaining(
        child: EmptyState(
          icon: query.isEmpty ? Icons.inventory_2_outlined : Icons.search_off_rounded,
          message: query.isEmpty ? 'لا توجد منتجات في المخزون' : 'لا توجد نتائج مطابقة لـ "$query"',
          actionLabel: query.isNotEmpty ? 'مسح البحث' : null,
          onAction: query.isNotEmpty
              ? () { _searchController.clear(); _onSearchChanged(''); }
              : null,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          if (constraints.maxWidth > 800) crossAxisCount = 4;
          else if (constraints.maxWidth > 500) crossAxisCount = 3;
          else crossAxisCount = 2;

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.72),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductCard(product: items[index]),
              childCount: items.length,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _rotationController.dispose();
    super.dispose();
  }
}
