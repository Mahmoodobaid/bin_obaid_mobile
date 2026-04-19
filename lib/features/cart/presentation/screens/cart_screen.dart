import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';
import '../../../../core/widgets/empty_state.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: _buildAppBar(context, ref, cart, isDark),
        body: cart.items.isEmpty
            ? _buildEmptyState(context)
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) => _buildCartItem(context, ref, cart.items[index], isDark),
                    ),
                  ),
                  _buildBottomCheckout(context, cart, isDark),
                ],
              ),
      ),
    );
  }

  // AppBar بتصميم عصري
  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref, dynamic cart, bool isDark) {
    return AppBar(
      elevation: 0,
      centerTitle: false,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سلة الطلبات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text('${cart.items.length} صنف جاهز للتوريد', style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ),
      actions: [
        if (cart.items.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
            onPressed: () => _showClearDialog(context, ref),
          ),
      ],
    );
  }

  // تصميم بطاقة المنتج الماسي
  Widget _buildCartItem(BuildContext context, WidgetRef ref, dynamic item, bool isDark) {
    return Dismissible(
      key: Key(item.product.sku),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(cartProvider.notifier).removeItem(item.product.sku),
      background: _buildDeleteBackground(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            _buildProductImage(item),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1),
                  const SizedBox(height: 4),
                  Text('سعر الوحدة: ${item.product.unitPrice} ريال', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _buildQuantityController(ref, item),
                ],
              ),
            ),
            _buildPriceTotal(item),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityController(WidgetRef ref, dynamic item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qBtn(Icons.remove, () => ref.read(cartProvider.notifier).decrementQuantity(item.product.sku)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          _qBtn(Icons.add, () => ref.read(cartProvider.notifier).incrementQuantity(item.product.sku)),
        ],
      ),
    );
  }

  Widget _qBtn(IconData icon, VoidCallback action) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        action();
      },
      child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 16, color: Colors.blue.shade900)),
    );
  }

  Widget _buildPriceTotal(dynamic item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${(item.quantity * item.product.unitPrice).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
        const Text('ريال', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBottomCheckout(BuildContext context, dynamic cart, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          _rowInfo('إجمالي السلة', '${cart.totalAmount.toStringAsFixed(2)} ريال', isLarge: true),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () => context.push('/invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: const Text('تأكيد الطلب وإصدار الفاتورة 🧾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String value, {bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isLarge ? 22 : 16)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.add_shopping_cart_rounded,
      message: 'سلة مؤسسة بن عبيد تنتظر اختياراتك',
      actionLabel: 'تصفح الأصناف الآن',
      onAction: () => context.go('/catalog'),
    );
  }

  Widget _buildProductImage(dynamic item) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: item.product.imageUrls.isNotEmpty
            ? Image.network(item.product.imageUrls.first, fit: BoxFit.cover)
            : const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 25),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 30),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تفريغ السلة؟'),
        content: const Text('سيتم حذف جميع الأصناف المختارة، هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // محاولة الاستدعاء الآمن
              try { ref.read(cartProvider.notifier).clear(); } catch (_) { 
                // إذا لم تكن دالة clear موجودة، نحذف العناصر يدوياً
                for (var item in ref.read(cartProvider).items) {
                  ref.read(cartProvider.notifier).removeItem(item.product.sku);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('نعم، احذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
