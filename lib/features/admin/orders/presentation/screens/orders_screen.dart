import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final List<Map<String, dynamic>> _orders = [
    {'id': '1001', 'customer': 'أحمد محمد', 'total': 1250.0, 'status': 'قيد الانتظار'},
    {'id': '1002', 'customer': 'خالد عبدالله', 'total': 3200.0, 'status': 'مكتمل'},
    {'id': '1003', 'customer': 'سارة علي', 'total': 850.0, 'status': 'ملغي'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الطلبات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _orders.length,
          itemBuilder: (ctx, i) {
            final o = _orders[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text(o['id'].toString().substring(0, 2))),
                title: Text('طلب #${o['id']}'),
                subtitle: Text('${o['customer']} - ${o['total']} ريال'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: o['status'] == 'مكتمل' ? Colors.green.shade100 : (o['status'] == 'قيد الانتظار' ? Colors.orange.shade100 : Colors.red.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(o['status']),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
