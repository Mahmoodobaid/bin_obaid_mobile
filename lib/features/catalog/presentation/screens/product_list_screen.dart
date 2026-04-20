import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:ui' as ui; // الحل النهائي لمشكلة rtl في بعض إصدارات فلاتر
import 'package:intl/intl.dart';

// الاستيرادات الأساسية لمشروع مؤسسة بن عبيد
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/shimmer_product_card.dart';
import '../../../../core/widgets/empty_state.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  // حالة المزامنة والتحكم بالواجهة
  double _syncProgress = 0.0;
  bool _isSyncing = false;
  String _syncStatusText = "";
  String _lastSyncTime = "لم يتم المزامنة";

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts();
      // استدعاء الفئات بأمان
      try {
        // إذا كان لديك categoryProvider مفعل، سيتم استدعاؤه هنا
        // ref.read(categoryProvider.notifier).loadCategories();
      } catch (e) {
        debugPrint("CategoryProvider setup check...");
      }
    });
  }

  // محرك المزامنة الاحترافي بمراحل ذكية
  Future<void> _handleProSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.1;
      _syncStatusText = "جاري الاتصال بسيرفر بن عبيد...";
    });

    try {
      HapticFeedback.mediumImpact();
      
      // المرحلة 1: تحديث المنتجات
      await ref.read(productProvider.notifier).refresh();
      setState(() { _syncProgress = 0.6; _syncStatusText = "تم تحديث الأصناف..."; });

      // المرحلة 2: تحديث إضافي (اختياري)
      setState(() { 
        _syncProgress = 1.0; 
        _syncStatusText = "اكتملت المزامنة ✅";
        _lastSyncTime = DateFormat('HH:mm').format(DateTime.now());
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث البيانات بنجاح: $_lastSyncTime'),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      _showDetailedErrorReport(e.toString());
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isSyncing = false);
      });
    }
  }

  void _showDetailedErrorReport(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 10), Text("تنبيه المزامنة", style: TextStyle(color: Colors.white))],
        ),
        content: Text("لم نتمكن من الوصول للسيرفر حالياً.\nتأكد من الإنترنت.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً")),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(productProvider.notifier).smartSearch(query);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(productProvider.notifier).loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl, // تحديد المكتبة الصريحة لضمان نجاح الـ Build
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildModernAppBar(isDark),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSearchSection(isDark),
                  _buildStatsRow(state),
                ],
              ),
            ),
            _buildProductGrid(state),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        floatingActionButton: _buildModernFAB(),
      ),
    );
  }

  Widget _buildModernAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 120.0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        title: const Text('أصناف مؤسسة بن عبيد', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
        IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white), onPressed: _handleProSync),
        _buildCartBadge(),
      ],
      bottom: _isSyncing 
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(value: _syncProgress, color: Colors.orange, backgroundColor: Colors.transparent),
            ) 
          : null,
    );
  }

  Widget _buildCartBadge() {
    return Stack(
      children: [
        IconButton(icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white), onPressed: () => context.push('/cart')),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: const Text('!', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        )
      ],
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
              hintText: 'ابحث باسم القطعة أو الكود (SKU)...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search_outlined, color: Colors.blue),
              suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: () { _searchController.clear(); _onSearchChanged(""); }) 
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

  Widget _buildStatsRow(dynamic state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("تم العثور على ${state.filteredProducts.length} صنف", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text("آخر تحديث: $_lastSyncTime", style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(dynamic state) {
    final products = state.filteredProducts;

    if (state.isLoading && products.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.72),
          delegate: SliverChildBuilderDelegate((_, __) => const ShimmerProductCard(), childCount: 6),
        ),
      );
    }

    if (products.isEmpty) {
      return SliverFillRemaining(
        child: EmptyState(
          icon: Icons.search_off_rounded, 
          message: 'لا توجد نتائج مطابقة لبحثك', 
          actionLabel: 'إعادة تعيين البحث', 
          onAction: () { _searchController.clear(); _onSearchChanged(""); }
        )
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, 
          mainAxisSpacing: 15, 
          crossAxisSpacing: 15, 
          childAspectRatio: 0.72
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(product: products[index]), 
          childCount: products.length
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    return FloatingActionButton.extended(
      onPressed: () => context.push('/barcode-scanner'),
      backgroundColor: const Color(0xFFF59E0B), // البرتقالي الماسي لعلامة "بن عبيد" التجارية
      elevation: 10,
      icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
      label: const Text("مسح سريع", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
