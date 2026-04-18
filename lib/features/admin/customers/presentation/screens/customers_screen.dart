import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final List<Map<String, String>> _customers = [
    {'name': 'أحمد محمد', 'phone': '770123456', 'address': 'صنعاء، حي حدة'},
    {'name': 'خالد عبدالله', 'phone': '771234567', 'address': 'عدن، المنصورة'},
    {'name': 'سارة علي', 'phone': '772345678', 'address': 'تعز، الحوبان'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قائمة العملاء'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _customers.length,
          itemBuilder: (ctx, i) {
            final c = _customers[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text(c['name']![0])),
                title: Text(c['name']!),
                subtitle: Text('${c['phone']} - ${c['address']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    // عرض تفاصيل العميل
                  },
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // إضافة عميل جديد
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
