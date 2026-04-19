import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعلانات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.campaign, color: Colors.blue),
                title: const Text('عرض خاص على الأسمنت'),
                subtitle: const Text('خصم 10% حتى نهاية الشهر'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.new_releases, color: Colors.green),
                title: const Text('منتج جديد: حديد تسليح'),
                subtitle: const Text('متوفر الآن في جميع الفروع'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
