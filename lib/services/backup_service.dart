import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class BackupService {
  static const String _backupPrefix = 'bin_obaid_backup';
  static const int _maxCustomerBackups = 5;

  /// إنشاء نسخة احتياطية لقاعدة البيانات المحلية (Hive)
  static Future<void> createBackup({required String userRole}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
      final fileName = userRole == 'admin'
          ? '${_backupPrefix}_admin_$monthKey.hive'
          : '${_backupPrefix}_customer_$timestamp.hive';
      final backupFile = File('${backupDir.path}/$fileName');

      // نسخ ملفات Hive (بافتراض أن الصندوق الافتراضي في documents)
      final hiveDir = Directory('${dir.path}/hive');
      if (await hiveDir.exists()) {
        // ضغط المجلد إلى ملف واحد (اختياري)
        await _copyDirectory(hiveDir, backupFile);
      }

      // تنظيف النسخ القديمة
      await _cleanupOldBackups(backupDir, userRole);
    } catch (e) {
      print('فشل إنشاء النسخة الاحتياطية: $e');
    }
  }

  static Future<void> _copyDirectory(Directory source, File target) async {
    // ببساطة ننسخ جميع الملفات داخل مجلد Hive إلى أرشيف tar (يمكن استخدام archive package)
    // للتبسيط، نكتفي بنسخ الملفات كما هي إلى مجلد backups مع اللاحقة
    // لكننا سنستخدم طريقة بسيطة: إنشاء ملف مضغوط يدويًا
    // نظرًا لعدم وجود مكتبة أرشيف، سنقوم بتخزين نسخة من ملفات Hive مباشرة
    final targetDir = Directory('${target.path}_files');
    if (!await targetDir.exists()) await targetDir.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.substring(source.path.length + 1);
        final destFile = File('${targetDir.path}/$relativePath');
        await destFile.parent.create(recursive: true);
        await entity.copy(destFile.path);
      }
    }
  }

  static Future<void> _cleanupOldBackups(Directory backupDir, String userRole) async {
    final backups = <File>[];
    await for (final entity in backupDir.list()) {
      if (entity is File && entity.path.contains(_backupPrefix)) {
        backups.add(entity);
      }
    }

    if (userRole == 'admin') {
      // الاحتفاظ بنسخة واحدة لكل شهر (آخر نسخة)
      final Map<String, File> monthly = {};
      for (final f in backups) {
        final name = f.path.split('/').last;
        if (name.contains('_admin_')) {
          final month = name.split('_admin_')[1].replaceAll('.hive', '');
          if (!monthly.containsKey(month) || f.lastModifiedSync().isAfter(monthly[month]!.lastModifiedSync())) {
            // حذف القديم إذا وجد
            if (monthly.containsKey(month)) await monthly[month]!.delete();
            monthly[month] = f;
          } else {
            await f.delete(); // حذف الأقدم
          }
        }
      }
    } else {
      // العملاء: الاحتفاظ بآخر 5 نسخ
      backups.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (int i = _maxCustomerBackups; i < backups.length; i++) {
        await backups[i].delete();
      }
    }
  }
}
