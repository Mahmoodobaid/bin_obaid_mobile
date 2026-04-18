import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationManagerScreen extends ConsumerStatefulWidget {
  const NotificationManagerScreen({super.key});

  @override
  ConsumerState<NotificationManagerScreen> createState() => _NotificationManagerScreenState();
}

class _NotificationManagerScreenState extends ConsumerState<NotificationManagerScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الإشعارات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('إرسال إشعار جماعي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'عنوان الإشعار')),
                      const SizedBox(height: 12),
                      TextField(controller: _bodyController, maxLines: 3, decoration: const InputDecoration(labelText: 'نص الإشعار')),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // إرسال الإشعار
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإشعار')));
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('إرسال'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('سجل الإشعارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text('إشعار #$i'),
                    subtitle: const Text('تم إرساله منذ يومين'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
