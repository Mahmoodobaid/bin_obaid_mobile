import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

// استيراد الملفات الخاصة بمشروعك
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // تحميل هادئ للبيانات (محلي + سحابي)
      ref.read(productProvider.notifier).loadProducts();
      ref.read(categoryProvider.notifier).loadCategories();
    });
  }

  // وظيفة المزامنة الشاملة مع السيرفر
  Future<void> _handleFullSync() async {
    HapticFeedback.mediumImpact(); // اهتزاز خفيف للإيحاء بالاحترافية
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 15),
            Text('جاري تحديث بيانات الأصناف من السيرفر...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    try {
      await ref.read(productProvider.notifier).refresh(); 
      await ref.read(categoryProvider.notifier).loadCategories();
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت المزامنة بنجاح ✅ - البيانات الآن محدثة'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، تعذر الاتصال بالسيرفر حالياً'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(productProvider.notifier).smartSearch(query);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      ref.read(productProvider.notifier).loadProducts(); // جلب الصفحة التالية تلقائياً
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final categoryState = ref.watch(categoryProvider);
    final products = state.filteredProducts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
        body: RefreshIndicator(
          onRefresh: () => ref.read(productProvider.notifier).refresh(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // الرأس الاحترافي
              _buildModernAppBar(isDark, state.isLoading),

              // محرك البحث وفلترة الفئات
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSearchInput(isDark),
                    _buildCategoryChips(categoryState, state),
                    if (state.isOfflineMode) _buildOfflineStatus(),
                  ],
                ),
              ),

              // منطقة عرض الأصناف
              _buildContentBody(state, products),

              // مساحة إضافية في الأسفل للـ FAB
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
        floatingActionButton: _buildBarcodeFAB(),
      ),
    );
  }

  Widget _buildModernAppBar(bool isDark, bool isLoading) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 120.0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        title: const Text('أصناف بن عبيد', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              colors: [Colors.blue.shade900, Colors.blue.shade700],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'مزامنة كاملة',
          icon: isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 28),
          onPressed: isLoading ? null : _handleFullSync,
        ),
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
          onPressed: () => context.push('/cart'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'ابحث عن صنف أو ماركة...',
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.blue),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.grey), onPressed: () {
                    _searchController.clear();
                    ref.read(productProvider.notifier).smartSearch('');
                  })
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(dynamic catState, dynamic prodState) {
    if (catState.isLoading) return const SizedBox(height: 10);
    return SizedBox(
      height: 65,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: catState.categories.length + 1,
        itemBuilder: (_, i) {
          final cat = i == 0 ? null : catState.categories[i - 1];
          final isSelected = prodState.selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ChoiceChip(
              label: Text(cat ?? 'الكل'),
              selected: isSelected,
              onSelected: (_) => ref.read(productProvider.notifier).setCategory(cat),
              selectedColor: Colors.blue.shade600,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.blue.shade900, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              backgroundColor: Colors.white,
              elevation: isSelected ? 4 : 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentBody(dynamic state, List products) {
    if (state.isLoading && products.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.78,
          ),
          delegate: SliverChildBuilderDelegate((_, __) => const ShimmerProductCard(), childCount: 6),
        ),
      );
    }

    if (products.isEmpty) {
      return SliverFillRemaining(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          message: 'لم يتم العثور على أي صنف بهذا الاسم',
          onAction: _handleFullSync,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(product: products[index]),
          childCount: products.length,
        ),
      ),
    );
  }

  Widget _buildBarcodeFAB() {
    return FloatingActionButton.extended(
      onPressed: () => context.push('/barcode-scanner'),
      backgroundColor: Colors.orange.shade800,
      icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
      label: const Text('فحص باركود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOfflineStatus() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade300)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          const Text('تعمل الآن من الذاكرة المحلية - اضغط مزامنة للتحديث', style: TextStyle(fontSize: 11, color: Colors.amber)),
        ],
      ),
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
