import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RolesPermissionsScreen extends ConsumerStatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  ConsumerState<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends ConsumerState<RolesPermissionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الصلاحيات والأدوار'),
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
                title: const Text('مدير'),
                subtitle: const Text('صلاحيات كاملة'),
                trailing: Switch(value: true, onChanged: (v) {}),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('مندوب'),
                subtitle: const Text('صلاحيات محدودة'),
                trailing: Switch(value: true, onChanged: (v) {}),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('عميل'),
                subtitle: const Text('صلاحيات أساسية'),
                trailing: Switch(value: true, onChanged: (v) {}),
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
