import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل النشاطات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 10,
          itemBuilder: (ctx, i) => ListTile(
            leading: const Icon(Icons.history),
            title: Text('نشاط #$i'),
            subtitle: const Text('تسجيل دخول - 2026-04-19 10:30'),
          ),
        ),
      ),
    );
  }
}
