// cart_screen.dart
// شاشة سلة التسوق - نسخة احترافية نهائية
// المسار: lib/features/cart/presentation/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/cart_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/quantity_selector.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _couponController = TextEditingController();
  bool _isApplyingCoupon = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isApplyingCoupon = true;
      _couponError = null;
    });
    final success = await ref.read(cartProvider.notifier).applyCoupon(code);
    if (mounted) {
      setState(() {
        _isApplyingCoupon = false;
        if (!success) {
          _couponError = 'كوبون غير صالح';
        } else {
          _couponController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تطبيق الخصم بنجاح'), backgroundColor: Colors.green),
          );
        }
      });
    }
  }

  void _removeCoupon() {
    ref.read(cartProvider.notifier).removeCoupon();
    setState(() => _couponError = null);
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('تفريغ السلة'),
        content: const Text('هل أنت متأكد من حذف جميع الأصناف من السلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
            },
            child: const Text('نعم، احذف الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat('#,##0.00', 'ar_EG');

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: _buildAppBar(cartState, isDark),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: cartState.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => ref.read(cartProvider.notifier).refreshPrices(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: cartState.items.length,
                          itemBuilder: (context, index) => _buildCartItem(
                            context,
                            cartState.items[index],
                            isDark,
                            currencyFormat,
                          ),
                        ),
                      ),
                    ),
                    _buildCouponSection(cartState, isDark, currencyFormat),
                    _buildBottomCheckout(cartState, isDark, currencyFormat),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CartState cart, bool isDark) {
    return AppBar(
      elevation: 0,
      centerTitle: false,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سلة الطلبات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text(
            '${cart.uniqueItemsCount} صنف • ${cart.totalQuantity} قطعة',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        if (cart.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
            onPressed: _showClearCartDialog,
            tooltip: 'تفريغ السلة',
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.shopping_cart_outlined,
      message: 'سلة التسوق فارغة',
      actionLabel: 'تصفح الأصناف',
      onAction: () => context.go('/catalog'),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, bool isDark, NumberFormat format) {
    final product = item.product;
    final effectivePrice = item.effectivePrice;
    final total = item.totalPrice;

    return Dismissible(
      key: Key(product.sku),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(cartProvider.notifier).removeItem(product.sku);
        HapticFeedback.lightImpact();
      },
      background: _buildDeleteBackground(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            _buildProductImage(product),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${format.format(effectivePrice)} ريال',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                      ),
                      if (item.customDiscount != null && item.customDiscount! > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('-${item.customDiscount!.toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.orange)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  QuantitySelector(
                    quantity: item.quantity,
                    onChanged: (newQty) => ref.read(cartProvider.notifier).setQuantity(product.sku, newQty),
                    min: 1,
                    max: 999,
                    size: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${format.format(total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                ),
                const SizedBox(height: 4),
                Text('ريال', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              )
            : const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.only(right: 25),
      decoration: BoxDecoration(
        color: Colors.red.shade500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildCouponSection(CartState cart, bool isDark, NumberFormat format) {
    if (cart.couponCode != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.green),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('كود الخصم: ${cart.couponCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('خصم ${cart.couponDiscountPercent}%', style: const TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _removeCoupon,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('إلغاء'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _couponController,
              decoration: InputDecoration(
                hintText: 'أدخل كود الخصم',
                border: InputBorder.none,
                errorText: _couponError,
                prefixIcon: const Icon(Icons.discount_outlined, size: 20),
              ),
              textAlign: TextAlign.start,
            ),
          ),
          if (_isApplyingCoupon)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            TextButton(
              onPressed: _applyCoupon,
              child: const Text('تطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckout(CartState cart, bool isDark, NumberFormat format) {
    final hasCoupon = cart.couponCode != null;
    final discountValue = cart.couponDiscountValue;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15)],
      ),
      child: Column(
        children: [
          // تفاصيل الأسعار
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المجموع الفرعي', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              Text('${format.format(cart.subtotal)} ريال', style: const TextStyle(fontSize: 14)),
            ],
          ),
          if (hasCoupon) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('خصم الكوبون (${cart.couponDiscountPercent}%)', style: TextStyle(color: Colors.green.shade700, fontSize: 14)),
                Text('- ${format.format(discountValue)} ريال', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(
                '${format.format(cart.total)} ريال',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => context.push('/checkout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 2,
              ),
              child: const Text(
                'متابعة إلى الدفع 🧾',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}