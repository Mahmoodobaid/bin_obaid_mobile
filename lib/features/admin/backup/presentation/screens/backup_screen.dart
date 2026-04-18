import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../services/backup_service.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('النسخ الاحتياطي'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await BackupService.createBackup(userRole: user?.role ?? 'customer');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية')));
                },
                icon: const Icon(Icons.backup),
                label: const Text('إنشاء نسخة احتياطية الآن'),
              ),
              const SizedBox(height: 24),
              const Text('النسخ المتوفرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: 3,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: const Icon(Icons.save),
                    title: Text('نسخة ${i + 1}'),
                    subtitle: Text('تاريخ: 2026-04-${19 - i}'),
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
