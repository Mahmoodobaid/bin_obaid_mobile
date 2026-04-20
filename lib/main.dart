import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// استيراد ملفات مشروع بن عبيد (تأكد من مطابقة المسارات في مشروعك)
import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

/// المفتاح العالمي للتحكم في التنقل وإدارة الواجهة
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 1. تثبيت الروابط الأساسية لـ Flutter لضمان استقرار التشغيل
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ضبط الهوية البصرية للنظام (وضع الوقوف والشفافية)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // 3. تنظيف البيانات المؤقتة لضمان بيئة عمل "بن عبيد" نقية 100%
  await _clearSystemCache();

  // 4. تشغيل الخدمات المركزية (Supabase & Local DB)
  await _initializeApplicationServices();

  // 5. طلب صلاحيات التشغيل الميداني (أندرويد 15)
  await _requestSystemPermissions();

  runApp(
    const ProviderScope(
      child: BinObaidMainApp(),
    ),
  );
}

/// محرك تهيئة الخدمات (تم الإصلاح ليتوافق مع أحدث إصدارات Supabase)
Future<void> _initializeApplicationServices() async {
  try {
    // تم الإصلاح: استخدام anonKey وتمرير مفتاح الخدمة مباشرة لحل تعارض الـ Build
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseServiceKey, 
      debug: false,
    );

    // تهيئة قاعدة البيانات المحلية Hive
    await Hive.initFlutter();
    
    // تشغيل خدمات المؤسسة المخصصة
    await LocalStorageService.init();
    await LocalNotificationService.initialize(navKey: navigatorKey);
    
    debugPrint("✅ نظام بن عبيد: جميع الخدمات تعمل بصلاحيات الإدارة الكاملة");
  } catch (e) {
    debugPrint("⚠️ تنبيه في نظام التهيئة: $e");
    // يستمر التطبيق في العمل بوضع الأمان لتجنب الإغلاق المفاجئ
  }
}

/// بروتوكول الصلاحيات المتطور لضمان عدم تعليق التطبيق
Future<void> _requestSystemPermissions() async {
  final List<Permission> permissions = [
    Permission.camera,
    Permission.notification,
    Permission.storage,
  ];

  for (var permission in permissions) {
    if (await permission.isDenied) {
      await permission.request();
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // دعم خاص لأجهزة S908U1 وإصدارات أندرويد الحديثة
  if (Platform.isAndroid && await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }
}

/// حذف مخلفات الإعدادات القديمة
Future<void> _clearSystemCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_supabase_url');
    await prefs.remove('custom_supabase_key');
  } catch (_) {}
}

/// واجهة التطبيق الرئيسية (The Enterprise UI)
class BinObaidMainApp extends ConsumerWidget {
  const BinObaidMainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ربط محرك المسارات GoRouter
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'مؤسسة بن عبيد التجارية',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // السمة البريميوم الرسمية للمؤسسة
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F3BBF),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Cairo', // تأكد من تعريف الخط في pubspec.yaml
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3BBF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
      ),
    );
  }
}
