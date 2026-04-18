import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
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

  static Future<bool> requestStorage(BuildContext context) async {
    return requestPermission(
      context: context,
      permission: Permission.storage,
      title: 'صلاحية التخزين',
      message: 'يحتاج التطبيق إلى الوصول إلى الملفات لاختيار الصور أو استيراد البيانات.',
    );
  }

  static Future<bool> requestCamera(BuildContext context) async {
    return requestPermission(
      context: context,
      permission: Permission.camera,
      title: 'صلاحية الكاميرا',
      message: 'يحتاج التطبيق إلى الوصول للكاميرا لالتقاط الصور.',
    );
  }
}
