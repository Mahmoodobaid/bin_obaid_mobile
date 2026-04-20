import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// استيراد ملفات مشروعك الأساسية (تأكد من وجود المسارات الصحيحة)
import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

/// المفتاح العالمي للتنقل واستدعاء الـ Context من أي مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 1. بروتوكول تثبيت الروابط الأساسية لـ Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. التحكم في واجهة النظام (اللون العلوي والوضع العمودي)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // 3. مسح الكاش القديم والمفاتيح المؤقتة لضمان بيئة عمل نقية
  await _clearSystemCache();

  // 4. تهيئة الخدمات مع معالجة الأخطاء الذكية (SafeBoot)
  await _initializeApplicationServices();

  // 5. بروتوكول طلب صلاحيات النظام المتطور
  await _requestSystemPermissions();

  // 6. تشغيل التطبيق مع نظام إدارة الحالة Riverpod
  runApp(
    const ProviderScope(
      child: BinObaidMainApp(),
    ),
  );
}

/// محرك تهيئة الخدمات السحابية والمحلية
Future<void> _initializeApplicationServices() async {
  try {
    // تشغيل محرك Supabase باستخدام مفتاح الصلاحيات الكاملة Service Role
    // لضمان الوصول لكافة الجداول وتجاوز قيود الـ RLS
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseServiceKey, // اعتماد مفتاح الإدارة الكاملة
      authOptions: const FlutterAuthOptions(
        localStorage: HiveLocalStorage(),
      ),
      debug: false,
    );

    // تشغيل قاعدة البيانات المحلية Hive للعمل دون إنترنت
    await Hive.initFlutter();
    
    // تشغيل خدمات التخزين والإشعارات الخاصة بمؤسسة بن عبيد
    await LocalStorageService.init();
    await LocalNotificationService.initialize(navKey: navigatorKey);
    
    debugPrint("✅ تم تفعيل نظام بن عبيد بصلاحيات المسؤول الكاملة");
  } catch (e) {
    debugPrint("⚠️ فشل في تهيئة بعض الخدمات: $e");
    // النظام يستمر في العمل حتى في حال فشل جزئي لضمان عدم توقف العمل
  }
}

/// نظام إدارة الصلاحيات المتقدم (تجاوز قيود أندرويد 15 و SDK 35)
Future<void> _requestSystemPermissions() async {
  // قائمة الصلاحيات الحيوية للعمل الميداني والمزامنة
  final List<Permission> permissions = [
    Permission.camera,        // لمسح الباركود
    Permission.notification,  // لتنبيهات النظام والمبيعات
    Permission.storage,       // لحفظ تقارير PDF
    Permission.requestInstallPackages, // لتحديث التطبيق داخلياً
  ];

  for (var permission in permissions) {
    final status = await permission.status;
    if (status.isDenied) {
      await permission.request();
      // تأخير طفيف لمنع تداخل نوافذ النظام في أندرويد
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  // صلاحية خاصة للوصول الكامل للملفات (ضرورية لإصدارات أندرويد الحديثة)
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }
}

/// تنظيف الذاكرة المؤقتة لضمان عدم تضارب البيانات القديمة
Future<void> _clearSystemCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // إزالة أي إعدادات يدوية سابقة قد تعيق الاتصال بالرابط الجديد
    await prefs.remove('custom_supabase_url');
    await prefs.remove('custom_supabase_key');
  } catch (_) {}
}

/// تطبيق بن عبيد الرئيسي - الواجهة والسمات (The Theme Engine)
class BinObaidMainApp extends ConsumerWidget {
  const BinObaidMainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مراقبة محرك التنقل GoRouter
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'مؤسسة بن عبيد التجارية',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // تطبيق الهوية البصرية الرسمية "البريميوم"
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F3BBF),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Cairo', // تأكد من إضافة الخط في pubspec.yaml
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 20, 
            color: Colors.white
          ),
          iconTheme: IconThemeData(color: Colors.blue),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3BBF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
        // تخصيص شكل الأزرار في كافة أنحاء التطبيق
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3BBF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
