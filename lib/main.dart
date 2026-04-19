import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// استيراد ملفات مشروعك الأساسية
import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 1. تثبيت روابط Flutter قبل أي عملية تهيئة
  WidgetsFlutterBinding.ensureInitialized();

  // 2. فرض الوضع العمودي للحفاظ على تناسق واجهة "بن عبيد"
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 3. تنظيف الكاش القديم لضمان عمل Supabase بشكل نظيف
  await _clearSystemCache();

  // 4. تهيئة الخدمات مع نظام حماية "Safe-Boot"
  await _initializeApplicationServices();

  // 5. بروتوكول طلب الصلاحيات المتسلسل لضمان عدم حجب النوافذ
  await _requestSystemPermissions();

  runApp(const ProviderScope(child: BinObaidMainApp()));
}

Future<void> _initializeApplicationServices() async {
  try {
    // تشغيل محرك البيانات Supabase
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    // تشغيل قاعدة البيانات المحلية Hive
    await Hive.initFlutter();
    
    // تشغيل الخدمات المخصصة للمؤسسة
    await LocalStorageService.init();
    await LocalNotificationService.initialize(navKey: navigatorKey);
    
    debugPrint("✅ تم تشغيل نظام بن عبيد بنجاح");
  } catch (e) {
    debugPrint("⚠️ تحذير في التهيئة: $e");
    // النظام مصمم ليبقى يعمل حتى في حال تعثر خدمة غير حيوية
  }
}

Future<void> _requestSystemPermissions() async {
  // ترتيب الصلاحيات من الأكثر أهمية
  final List<Permission> permissions = [
    Permission.camera,
    Permission.notification,
    Permission.location,
    Permission.photos,
  ];

  for (var permission in permissions) {
    final status = await permission.status;
    if (status.isDenied || status.isLimited) {
      await permission.request();
      // تأخير تقني لمنع تداخل شاشات النظام
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // صلاحية الوصول الكامل للملفات لأجهزة أندرويد الحديثة
  if (Platform.isAndroid && await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }
}

Future<void> _clearSystemCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('custom_supabase_url');
  await prefs.remove('custom_supabase_key');
}

class BinObaidMainApp extends ConsumerWidget {
  const BinObaidMainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'مؤسسة بن عبيد التجارية',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: ThemeMode.dark, // الاعتماد على الثيم المظلم بشكل افتراضي
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F3BBF),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3BBF),
          brightness: Brightness.dark,
        ),
      ),
    );
  }
}

/// واجهة الطوارئ عند فقدان الاتصال
class NoInternetApp extends StatelessWidget {
  const NoInternetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 90, color: Colors.orangeAccent),
              const SizedBox(height: 24),
              const Text('لا يوجد اتصال بالشبكة', 
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('تطبيق بن عبيد يحتاج للإنترنت للمزامنة مع السيرفر الرئيسي في أول مرة.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => exit(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('إعادة المحاولة'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
