import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
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
    // جلب البيانات المحلية فوراً عند الدخول
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // تحميل هادئ (Silent Load) من البيانات المحلية/السيرفر
      ref.read(productProvider.notifier).loadProducts();
      ref.read(categoryProvider.notifier).loadCategories();
    });
  }

  // ميزة المزامنة الشاملة (Full Manual Sync)
  Future<void> _handleFullSync() async {
    // إظهار رسالة تنبيه للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري مزامنة الأصناف مع السيرفر...'), duration: Duration(seconds: 1)),
    );
    
    // تنفيذ المزامنة من خلال النوتيفاير الخاص بك
    await ref.read(productProvider.notifier).refresh(); 
    await ref.read(categoryProvider.notifier).loadCategories();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت المزامنة بنجاح ✅'), backgroundColor: Colors.green),
      );
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
          physics: const BouncingScrollPhysics(),
          slivers: [
            // AppBar المطور مع زر المزامنة
            SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: 100,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
              title: const Text('أصناف بن عبيد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              actions: [
                // زر المزامنة المستقل والاحترافي
                IconButton(
                  tooltip: 'مزامنة شاملة',
                  icon: state.isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.sync_rounded, color: Colors.white),
                  onPressed: state.isLoading ? null : _handleFullSync,
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  onPressed: () => context.push('/cart'),
                ),
              ],
            ),

            // محرك البحث وفلترة الفئات
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSearchSection(isDark),
                  _buildCategoryFilter(categoryState, state),
                  if (state.isOfflineMode) _buildOfflineBanner(),
                ],
              ),
            ),

            // عرض البيانات (الشبكة الاحترافية)
            state.isLoading && products.isEmpty
                ? _buildShimmerGrid()
                : products.isEmpty 
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : _buildProductGrid(products),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'ابحث عن صنف، كود، أو ماركة...',
          prefixIcon: const Icon(Icons.search, color: Colors.blue),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  _searchController.clear();
                  ref.read(productProvider.notifier).smartSearch('');
                })
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(dynamic catState, dynamic prodState) {
    if (catState.isLoading) return const SizedBox(height: 10);
    return SizedBox(
      height: 55,
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
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(List products) {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      slivers: [
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => ProductCard(product: products[index]),
            childCount: products.length,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      slivers: [
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate((_, __) => const ShimmerProductCard(), childCount: 6),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      message: 'لم نجد أي أصناف مطابقة لطلبك',
      actionLabel: 'تحديث الكل',
      onAction: _handleFullSync,
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Text('أنت تعمل في وضع الأوفلاين (البيانات المحلية)', style: TextStyle(color: Colors.orange, fontSize: 12)),
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
