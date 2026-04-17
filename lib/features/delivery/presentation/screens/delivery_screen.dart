import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/delivery_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});
  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(deliveryProvider.notifier).loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات التوصيل'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.read(deliveryProvider.notifier).loadOrders()),
            IconButton(icon: const Icon(Icons.logout), onPressed: () { ref.read(authProvider.notifier).logout(); context.go('/login'); }),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.orders.isEmpty
                ? const Center(child: Text('لا توجد طلبات مسندة إليك'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.orders.length,
                    itemBuilder: (c, i) {
                      final o = state.orders[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('فاتورة #${o.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _row(Icons.person, o.customerName),
                            _row(Icons.phone, o.customerPhone),
                            _row(Icons.location_on, o.customerAddress),
                            _row(Icons.money, '${o.totalAmount.toStringAsFixed(2)} ريال'),
                            const SizedBox(height: 12),
                            if (o.status == 'pending' || o.status == 'assigned')
                              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                ElevatedButton.icon(onPressed: () => ref.read(deliveryProvider.notifier).updateOrderStatus(o.id, 'picked_up'), icon: const Icon(Icons.check_circle), label: const Text('تم الاستلام'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue)),
                                ElevatedButton.icon(onPressed: () => ref.read(deliveryProvider.notifier).updateOrderStatus(o.id, 'delivered'), icon: const Icon(Icons.done_all), label: const Text('تم التوصيل'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
                              ]),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(text)]));
}
