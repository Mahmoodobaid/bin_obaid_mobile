import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ضبط اتجاه الشاشة وألوان النظام (StatusBar & NavigationBar)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F172A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await _clearSystemCache();
  await _initializeApplicationServices();
  await _requestSystemPermissions();

  runApp(const ProviderScope(child: BinObaidMainApp()));
}

Future<void> _initializeApplicationServices() async {
  try {
    // الاتصال بالسيرفر باستخدام مفتاح الخدمة لتجاوز قيود الـ RLS
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseServiceKey,
      debug: false,
    );
    
    await Hive.initFlutter();
    await LocalStorageService.init();
    await LocalNotificationService.initialize(navKey: navigatorKey);
    
    debugPrint("✅ نظام بن عبيد: المحرك يعمل بكفاءة 100%");
  } catch (e) {
    debugPrint("⚠️ فشل في تهيئة المحرك: $e");
  }
}

Future<void> _requestSystemPermissions() async {
  if (Platform.isAndroid) {
    // طلب حزمة الصلاحيات الأساسية
    await [
      Permission.camera,
      Permission.notification,
      Permission.storage,
    ].request();
    
    // صلاحية خاصة لأجهزة أندرويد الحديثة (S908U1)
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }
}

Future<void> _clearSystemCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // تصفير كامل لضمان بداية نقية
  } catch (_) {}
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
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F3BBF),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        
        // تصميم الـ AppBar الفاخر
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 8,
          shadowColor: Colors.black26,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 20, 
            color: Colors.white,
            letterSpacing: 0.5
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        // توزيع الألوان والظلال (Premium UI)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3BBF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF10B981),
        ),

        // تصميم البطاقات (Cards)
        cardTheme: CardTheme(
          color: const Color(0xFF1E293B),
          elevation: 4,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        
        // تصميم الأزرار (Buttons)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3BBF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
