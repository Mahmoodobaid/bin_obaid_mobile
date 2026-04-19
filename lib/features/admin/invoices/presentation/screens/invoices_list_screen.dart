import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  final List<Map<String, dynamic>> _invoices = [
    {'number': 'INV-1001', 'customer': 'أحمد محمد', 'amount': 1250.0, 'date': '2026-04-19'},
    {'number': 'INV-1002', 'customer': 'خالد عبدالله', 'amount': 3200.0, 'date': '2026-04-18'},
    {'number': 'INV-1003', 'customer': 'سارة علي', 'amount': 850.0, 'date': '2026-04-17'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قائمة الفواتير'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _invoices.length,
          itemBuilder: (ctx, i) {
            final inv = _invoices[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.receipt),
                title: Text(inv['number']),
                subtitle: Text('${inv['customer']} - ${inv['date']}'),
                trailing: Text('${inv['amount']} ريال', style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  // عرض تفاصيل الفاتورة
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
