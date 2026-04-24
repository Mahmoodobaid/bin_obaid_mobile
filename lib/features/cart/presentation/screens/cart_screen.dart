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
        appBar: AppBar(title: Text('السلة (${cart.items.length})')),
        body: cart.items.isEmpty
            ? EmptyState(icon: Icons.shopping_cart_outlined, message: 'السلة فارغة', actionLabel: 'تصفح', onAction: () => context.go('/catalog'))
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (c, i) {
                        final it = cart.items[i];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            leading: it.product.imageUrls.isNotEmpty ? Image.network(it.product.imageUrls.first, width: 50, fit: BoxFit.cover) : const Icon(Icons.image),
                            title: Text(it.product.name),
                            subtitle: Text('${it.quantity} x ${it.product.unitPrice} ريال'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove), onPressed: () => ref.read(cartProvider.notifier).decrementQuantity(it.product.sku)),
                                Text('${it.quantity}'),
                                IconButton(icon: const Icon(Icons.add), onPressed: () => ref.read(cartProvider.notifier).incrementQuantity(it.product.sku)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('الإجمالي: ${cart.total.toStringAsFixed(2)} ريال', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ElevatedButton(onPressed: () => context.push('/invoice'), child: const Text('متابعة')),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}
