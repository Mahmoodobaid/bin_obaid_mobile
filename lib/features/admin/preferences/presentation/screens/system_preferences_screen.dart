import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SystemPreferencesScreen extends ConsumerStatefulWidget {
  const SystemPreferencesScreen({super.key});

  @override
  ConsumerState<SystemPreferencesScreen> createState() => _SystemPreferencesScreenState();
}

class _SystemPreferencesScreenState extends ConsumerState<SystemPreferencesScreen> {
  bool _autoBackup = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفضيلات النظام'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('النسخ الاحتياطي التلقائي'),
              value: _autoBackup,
              onChanged: (v) => setState(() => _autoBackup = v),
            ),
            SwitchListTile(
              title: const Text('الوضع الداكن'),
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
            ),
          ],
        ),
      ),
    );
  }
}
