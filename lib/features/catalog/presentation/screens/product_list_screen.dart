import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:intl/intl.dart';

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
  
  // متغيرات حالة المزامنة المتقدمة
  double _syncProgress = 0.0;
  bool _isSyncing = false;
  String _syncStatusText = "";
  String _lastSyncTime = "لم يتم المزامنة بعد";

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts();
      ref.read(categoryProvider.notifier).loadCategories();
    });
  }

  // محرك المزامنة الاحترافي مع مراحل التقدم
  Future<void> _handleProSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatusText = "بدء الاتصال بالسيرفر...";
    });

    try {
      HapticFeedback.mediumImpact();
      
      // المرحلة 1: فحص الشبكة والاتصال
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() { _syncProgress = 0.2; _syncStatusText = "جاري التحقق من قاعدة البيانات..."; });

      // المرحلة 2: جلب البيانات من Supabase
      await ref.read(productProvider.notifier).refresh();
      setState(() { _syncProgress = 0.6; _syncStatusText = "تم جلب البيانات، جاري الحفظ محلياً..."; });

      // المرحلة 3: تحديث الفئات و Hive
      await ref.read(categoryProvider.notifier).loadCategories();
      setState(() { _syncProgress = 0.9; _syncStatusText = "تحديث الفهارس الذكية..."; });

      await Future.delayed(const Duration(milliseconds: 300));
      
      setState(() {
        _syncProgress = 1.0;
        _lastSyncTime = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت المزامنة بنجاح ✅'), backgroundColor: Colors.green),
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

  // نافذة تقرير الأخطاء المفصل عند فشل الوصول للسيرفر
  void _showDetailedErrorReport(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [Icon(Icons.error_outline, color: Colors.red), SizedBox(width: 10), Text("تقرير فشل المزامنة")],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("تعذر الوصول إلى سيرفر مؤسسة بن عبيد:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text(error, style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12)),
              ),
              const SizedBox(height: 12),
              const Text("التوصية: تأكد من جودة الإنترنت أو صلاحيات التطبيق.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("حاول لاحقاً")),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
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
    final categoryState = ref.watch(categoryProvider);
    final products = state.filteredProducts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // AppBar مع شريط التقدم المدمج
            _buildAppBar(isDark),

            // قسم البحث والإحصائيات
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSearchSection(isDark),
                  _buildSyncStatusBar(),
                  _buildCategoryFilter(categoryState, state),
                ],
              ),
            ),

            // شبكة المنتجات
            _buildProductContent(state, products),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        floatingActionButton: _buildBarcodeFAB(),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
      title: const Text('أصناف بن عبيد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      actions: [
        IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white), onPressed: _handleProSync),
        IconButton(icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white), onPressed: () => context.push('/cart')),
      ],
      bottom: _isSyncing 
        ? PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: Column(
              children: [
                LinearProgressIndicator(value: _syncProgress, backgroundColor: Colors.white24, color: Colors.orange),
                Container(
                  width: double.infinity,
                  color: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(_syncStatusText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                )
              ],
            ),
          ) 
        : null,
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'ابحث عن اسم، كود SKU، أو ماركة...',
            prefixIcon: const Icon(Icons.search, color: Colors.blue),
            suffixIcon: _searchController.text.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _onSearchChanged(""); }) 
                : const Icon(Icons.mic, color: Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("آخر مزامنة: $_lastSyncTime", style: const TextStyle(color: Colors.grey, fontSize: 10)),
          if (ref.watch(productProvider).isOfflineMode)
            const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 14),
                SizedBox(width: 4),
                Text("وضع الأوفلاين", style: TextStyle(color: Colors.orange, fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(dynamic catState, dynamic prodState) {
    if (catState.isLoading) return const SizedBox(height: 50);
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: catState.categories.length + 1,
        itemBuilder: (_, i) {
          final cat = i == 0 ? null : catState.categories[i - 1];
          final isSelected = prodState.selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(cat ?? 'الكل'),
              selected: isSelected,
              onSelected: (_) => ref.read(productProvider.notifier).setCategory(cat),
              selectedColor: Colors.blue,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductContent(dynamic state, List products) {
    if (state.isLoading && products.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
          delegate: SliverChildBuilderDelegate((_, __) => const ShimmerProductCard(), childCount: 6),
        ),
      );
    }

    if (products.isEmpty) {
      return SliverFillRemaining(child: EmptyState(icon: Icons.search_off, message: 'لم يتم العثور على أصناف', actionLabel: 'تحديث البيانات', onAction: _handleProSync));
    }

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
        delegate: SliverChildBuilderDelegate((context, index) => ProductCard(product: products[index]), childCount: products.length),
      ),
    );
  }

  Widget _buildBarcodeFAB() {
    return FloatingActionButton.extended(
      onPressed: () => context.push('/barcode-scanner'),
      backgroundColor: Colors.orange.shade800,
      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
      label: const Text("فحص باركود", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
