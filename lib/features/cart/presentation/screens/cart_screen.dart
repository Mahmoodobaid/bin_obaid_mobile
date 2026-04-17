import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';
import '../../../../core/widgets/empty_state.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('سلة المشتريات (${cart.items.length})'),
          actions: [
            if (cart.items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref.read(cartProvider.notifier).clearCart(),
              ),
          ],
        ),
        body: cart.items.isEmpty
            ? EmptyState(
                icon: Icons.shopping_cart_outlined,
                message: 'السلة فارغة',
                actionLabel: 'تصفح المنتجات',
                onAction: () => context.go('/catalog'),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return Dismissible(
                          key: Key(item.product.sku),
                          direction: DismissDirection.endToStart,
                          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                          onDismissed: (_) => ref.read(cartProvider.notifier).removeItem(item.product.sku),
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: item.product.imageUrls.isNotEmpty
                                  ? Image.network(item.product.imageUrls.first, width: 50, height: 50, fit: BoxFit.cover)
                                  : const Icon(Icons.image),
                              title: Text(item.product.name),
                              subtitle: Text('${item.product.unitPrice} ريال'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.remove), onPressed: () => ref.read(cartProvider.notifier).decrementQuantity(item.product.sku)),
                                  Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                                  IconButton(icon: const Icon(Icons.add), onPressed: () => ref.read(cartProvider.notifier).incrementQuantity(item.product.sku)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الإجمالي:', style: TextStyle(fontSize: 16)),
                            Text('${cart.totalAmount.toStringAsFixed(2)} ريال', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => context.push('/invoice'),
                          child: const Text('متابعة الشراء'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
