import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// طلب صلاحية مع شرح مخصص
  static Future<bool> requestPermission({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
  }) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      _showSettingsDialog(context, title, message);
      return false;
    }
    // طلب الصلاحية
    final result = await permission.request();
    if (result.isGranted) return true;
    if (result.isPermanentlyDenied) {
      _showSettingsDialog(context, title, message);
    }
    return false;
  }

  static void _showSettingsDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('$message\n\nالرجاء تفعيل الصلاحية من إعدادات التطبيق.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  /// طلب صلاحية الكاميرا (مع الشرح المناسب)
  static Future<bool> requestCamera(BuildContext context) async {
    return requestPermission(
      context: context,
      permission: Permission.camera,
      title: 'صلاحية الكاميرا',
      message: 'يحتاج التطبيق إلى الوصول للكاميرا لالتقاط الصور.',
    );
  }

  /// طلب صلاحية التخزين للصور (قراءة الصور من المعرض)
  static Future<bool> requestStorage(BuildContext context) async {
    // بالنسبة للإصدارات الحديثة من أندرويد، صلاحية قراءة الصور هي photos أو storage
    Permission permission;
    if (await Permission.photos.isSupported) {
      permission = Permission.photos;
    } else if (await Permission.storage.isSupported) {
      permission = Permission.storage;
    } else {
      permission = Permission.storage; // fallback
    }
    return requestPermission(
      context: context,
      permission: permission,
      title: 'صلاحية التخزين',
      message: 'يحتاج التطبيق إلى الوصول إلى معرض الصور لاختيار الصور.',
    );
  }

  /// طلب صلاحية الموقع (للخرائط أو العناوين)
  static Future<bool> requestLocation(BuildContext context) async {
    return requestPermission(
      context: context,
      permission: Permission.location,
      title: 'صلاحية الموقع',
      message: 'يحتاج التطبيق إلى الوصول للموقع لتحديد العنوان.',
    );
  }

  /// طلب صلاحية الإشعارات (Android 13+)
  static Future<bool> requestNotifications(BuildContext context) async {
    if (await Permission.notification.isSupported) {
      return requestPermission(
        context: context,
        permission: Permission.notification,
        title: 'صلاحية الإشعارات',
        message: 'يحتاج التطبيق إلى إرسال الإشعارات لتنبيهك بالطلبات الجديدة.',
      );
    }
    return true; // غير مطلوبة
  }
}
