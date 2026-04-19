import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsManagerScreen extends ConsumerStatefulWidget {
  const PermissionsManagerScreen({super.key});

  @override
  ConsumerState<PermissionsManagerScreen> createState() => _PermissionsManagerScreenState();
}

class _PermissionsManagerScreenState extends ConsumerState<PermissionsManagerScreen>
    with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _permissionsList = [
    {
      'title': 'التخزين والملفات',
      'subtitle': 'لإدارة النسخ الاحتياطي وحفظ الفواتير والصور',
      'icon': Icons.folder_shared,
      'permission': Permission.storage,
    },
    {
      'title': 'الصور والوسائط',
      'subtitle': 'للوصول إلى معرض الصور لإضافة صور المنتجات',
      'icon': Icons.photo_library_rounded,
      'permission': Permission.photos,
    },
    {
      'title': 'الكاميرا',
      'subtitle': 'لمسح الباركود وتصوير المنتجات والمرفقات',
      'icon': Icons.camera_alt_rounded,
      'permission': Permission.camera,
    },
    {
      'title': 'الموقع الجغرافي',
      'subtitle': 'لتحديد موقع العميل أو المندوب بدقة',
      'icon': Icons.location_on_rounded,
      'permission': Permission.location,
    },
    {
      'title': 'الإشعارات',
      'subtitle': 'لتنبيهك بنقص المخزون وحالة الطلبات',
      'icon': Icons.notifications_active_rounded,
      'permission': Permission.notification,
    },
  ];

  Map<Permission, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final Map<Permission, PermissionStatus> updatedStatuses = {};
    for (var item in _permissionsList) {
      final perm = item['permission'] as Permission;
      updatedStatuses[perm] = await perm.status;
    }
    if (mounted) setState(() => _statuses = updatedStatuses);
  }

  Future<void> _handlePermission(Permission perm) async {
    final status = await perm.request();
    if (status.isPermanentlyDenied) {
      _showSettingsDialog();
    }
    _refreshPermissions();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل الصلاحية يدوياً'),
        content: const Text(
          'لقد رفضت هذه الصلاحية بشكل دائم. يجب تفعيلها من إعدادات النظام لاستخدام الميزات المرتبطة بها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(ctx);
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
        appBar: AppBar(
          title: const Text('مركز إدارة الصلاحيات'),
          centerTitle: true,
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshPermissions,
              tooltip: 'تحديث الحالة',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildHeaderInfo(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _permissionsList.length,
                itemBuilder: (ctx, i) => _buildPermissionCard(_permissionsList[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: const Column(
        children: [
          Icon(Icons.security_rounded, color: Color(0xFFD4AF37), size: 50),
          SizedBox(height: 10),
          Text(
            'تحكم في خصوصية وأمان النظام',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'نظام محلات بن عبيد يطلب فقط الصلاحيات اللازمة للعمل',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(Map<String, dynamic> item) {
    final perm = item['permission'] as Permission;
    final status = _statuses[perm] ?? PermissionStatus.denied;

    Color statusColor;
    String statusText;

    if (status.isGranted) {
      statusColor = Colors.green;
      statusText = 'مسموح';
    } else if (status.isLimited) {
      statusColor = Colors.orange;
      statusText = 'محدود';
    } else {
      statusColor = Colors.grey;
      statusText = 'غير مسموح';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(item['icon'], color: statusColor),
        ),
        title: Text(
          item['title'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          item['subtitle'],
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        trailing: _buildActionButton(status, perm),
      ),
    );
  }

  Widget _buildActionButton(PermissionStatus status, Permission perm) {
    if (status.isGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'نشط',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _handlePermission(perm),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B263B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: const Text('تفعيل', style: TextStyle(fontSize: 12)),
    );
  }
}
