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
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('سلة المشتريات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
              Text('${cart.items.length} أصناف في السلة', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          actions: [
            if (cart.items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                onPressed: () => _showClearCartDialog(context, ref),
                tooltip: 'تفريغ السلة',
              ),
          ],
        ),
        body: cart.items.isEmpty
            ? EmptyState(
                icon: Icons.shopping_basket_outlined,
                message: 'سلتك فارغة حالياً.. ابدأ بإضافة الأصناف',
                actionLabel: 'اذهب للكتالوج',
                onAction: () => context.go('/catalog'),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return _buildCartItem(context, ref, item, isDark);
                      },
                    ),
                  ),
                  _buildCheckoutSection(context, cart, isDark),
                ],
              ),
      ),
    );
  }

  // بناء بطاقة المنتج الاحترافية
  Widget _buildCartItem(BuildContext context, WidgetRef ref, dynamic item, bool isDark) {
    return Dismissible(
      key: Key(item.product.sku),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 30),
      ),
      onDismissed: (_) {
        ref.read(cartProvider.notifier).removeItem(item.product.sku);
        HapticFeedback.lightImpact();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // صورة المنتج
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey.withOpacity(0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: item.product.imageUrls.isNotEmpty
                      ? Image.network(item.product.imageUrls.first, fit: BoxFit.cover)
                      : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 15),
              // تفاصيل المنتج
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text('${item.product.unitPrice} ريال', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    // أزرار التحكم في الكمية
                    Row(
                      children: [
                        _qtyBtn(Icons.remove, () => ref.read(cartProvider.notifier).decrementQuantity(item.product.sku)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        _qtyBtn(Icons.add, () => ref.read(cartProvider.notifier).incrementQuantity(item.product.sku)),
                      ],
                    ),
                  ],
                ),
              ),
              // السعر الإجمالي للسطر
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(item.quantity * item.product.unitPrice).toStringAsFixed(2)}', 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green)),
                  const Text('ريال', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: Colors.blue.shade900),
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
      ),
    );
  }

  // قسم الدفع والإجمالي (التصميم الحديث السفلي)
  Widget _buildCheckoutSection(BuildContext context, dynamic cart, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي القيمة', style: TextStyle(fontSize: 16, color: Colors.grey)),
                Text('${cart.totalAmount.toStringAsFixed(2)} ريال', 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.blue.shade900)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => context.push('/invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 5,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('إتمام الفاتورة وتحصيل المبلغ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفريغ السلة؟'),
        content: const Text('هل أنت متأكد من حذف جميع الأصناف من السلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(context);
            }, 
            child: const Text('حذف الكل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
