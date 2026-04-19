import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsManagerScreen extends ConsumerStatefulWidget {
  const PermissionsManagerScreen({super.key});
  @override
  ConsumerState<PermissionsManagerScreen> createState() => _PermissionsManagerScreenState();
}

class _PermissionsManagerScreenState extends ConsumerState<PermissionsManagerScreen> {
  final List<Map<String, dynamic>> _permissions = [
    {'name': 'التخزين', 'icon': Icons.storage, 'permission': Permission.storage},
    {'name': 'الكاميرا', 'icon': Icons.camera_alt, 'permission': Permission.camera},
    {'name': 'الموقع', 'icon': Icons.location_on, 'permission': Permission.location},
    {'name': 'الإشعارات', 'icon': Icons.notifications, 'permission': Permission.notification},
    {'name': 'الصور والوسائط', 'icon': Icons.photo_library, 'permission': Permission.photos},
  ];

  Map<Permission, bool> _status = {};

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    final newStatus = <Permission, bool>{};
    for (var p in _permissions) {
      final perm = p['permission'] as Permission;
      newStatus[perm] = await perm.isGranted;
    }
    setState(() => _status = newStatus);
  }

  Future<void> _request(Permission perm) async {
    final result = await perm.request();
    setState(() => _status[perm] = result.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إدارة الصلاحيات'), centerTitle: true),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _permissions.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (ctx, i) {
            final item = _permissions[i];
            final perm = item['permission'] as Permission;
            final isGranted = _status[perm] ?? false;
            return ListTile(
              leading: Icon(item['icon'], color: isGranted ? Colors.green : Colors.grey),
              title: Text(item['name']),
              trailing: isGranted
                  ? const Chip(label: Text('مسموح', style: TextStyle(color: Colors.green)))
                  : ElevatedButton(onPressed: () => _request(perm), child: const Text('منح الصلاحية')),
            );
          },
        ),
      ),
    );
  }
}
