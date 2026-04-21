import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تثبيت الاتجاه الرأسي وتخصيص شريط الحالة
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F172A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // تنظيف الذاكرة المؤقتة للصور والملفات (لا تمسح بيانات المستخدم)
  await _clearTemporaryCache();

  // تهيئة الخدمات الأساسية (شبكة، تخزين، إشعارات)
  await _initializeApplicationServices();

  // طلب الصلاحيات الضرورية فقط
  await _requestEssentialPermissions();

  // تشغيل التطبيق
  runApp(const ProviderScope(child: BinObaidMainApp()));

  // تشغيل التشخيص الكامل في الخلفية بعد تحميل الواجهة (اختياري)
  Future.microtask(() => _runFullDiagnostics());
}

Future<void> _initializeApplicationServices() async {
  try {
    // تهيئة Supabase
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      debug: false, // يفضل false في الإنتاج
    );
    debugPrint('✅ Supabase initialized');

    // تهيئة التخزين المحلي
    await Hive.initFlutter();
    await LocalStorageService.init();

    // تهيئة الإشعارات المحلية
    await LocalNotificationService.initialize(navKey: navigatorKey);

    debugPrint('✅ جميع خدمات التطبيق جاهزة');
  } catch (e) {
    debugPrint('❌ فشل في تهيئة الخدمات: $e');
  }
}

Future<void> _requestEssentialPermissions() async {
  if (Platform.isAndroid) {
    // الصلاحيات الأساسية فقط
    await [
      Permission.notification,
      Permission.storage,
    ].request();

    // صلاحية الكاميرا تطلب فقط عند استخدامها (في شاشة التصوير)
  }
}

Future<void> _clearTemporaryCache() async {
  try {
    // تنظيف ذاكرة التخزين المؤقت للصور المحملة عبر الشبكة
    await CachedNetworkImage.evictFromCache('');
    // حذف الملفات المؤقتة القديمة (إن وجدت)
    final tempDir = Directory.systemTemp;
    if (tempDir.existsSync()) {
      for (final file in tempDir.listSync().whereType<File>()) {
        if (file.path.endsWith('.tmp')) {
          file.deleteSync();
        }
      }
    }
  } catch (_) {}
}

// ============================================================================
//                          التشخيص الكامل (Full Diagnostics)
//              يُنفذ في الخلفية ولا يؤثر على سرعة بدء التطبيق
// ============================================================================

Future<void> _runFullDiagnostics() async {
  // انتظر قليلاً حتى تستقر الواجهة
  await Future.delayed(const Duration(milliseconds: 500));

  debugPrint('═══════════════════════════════════════');
  debugPrint('📱 تقرير تشخيص الاتصال - بن عبيد التجارية');
  debugPrint('═══════════════════════════════════════');
  debugPrint('📅 ${DateTime.now()}');

  // 1. معلومات الجهاز
  debugPrint('📌 معلومات الجهاز:');
  debugPrint('   النظام: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  debugPrint('   التطبيق: com.binobaid.trading');

  // 2. حالة الشبكة
  final connectivity = await Connectivity().checkConnectivity();
  debugPrint('🌐 حالة الشبكة: $connectivity');

  // 3. اختبار DNS لـ Supabase
  try {
    final result = await InternetAddress.lookup('ackxfnznrjufhppaznjd.supabase.co');
    debugPrint('🔍 DNS Lookup: ${result.map((e) => e.address).join(', ')}');
  } catch (e) {
    debugPrint('❌ فشل DNS: $e');
  }

  // 4. اختبار الاتصال المباشر بـ Supabase REST API
  final client = Supabase.instance.client;
  try {
    final data = await client.from('products').select('*').limit(1);
    debugPrint('✅ نجح الاتصال بقاعدة البيانات. عدد المنتجات المسترجعة: ${data.length}');
  } catch (e) {
    debugPrint('❌ فشل الاتصال بقاعدة البيانات: $e');
  }

  // 5. اختبار جدول users (للمصادقة)
  try {
    final userData = await client.from('users').select('id').limit(1);
    debugPrint('✅ جدول users متاح. عدد المستخدمين: ${userData.length}');
  } catch (e) {
    debugPrint('⚠️ جدول users غير متاح: $e');
  }

  // 6. اختبار المصادقة (بدون تسجيل دخول)
  try {
    final session = client.auth.currentSession;
    debugPrint('🔐 الجلسة الحالية: ${session?.user.email ?? 'لا يوجد جلسة'}');
  } catch (e) {
    debugPrint('⚠️ خطأ في فحص الجلسة: $e');
  }

  // 7. إعدادات المفاتيح
  debugPrint('🔑 نوع المفتاح المستخدم: anon (عميل)');
  debugPrint('   طول المفتاح: ${AppConfig.supabaseAnonKey.length} حرفاً');

  debugPrint('═══════════════════════════════════════');
  debugPrint('✅ انتهى التشخيص');
  debugPrint('═══════════════════════════════════════');
}

// ============================================================================
//                          التطبيق الرئيسي
// ============================================================================

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 8,
          shadowColor: Colors.black26,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3BBF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF10B981),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E293B),
          elevation: 4,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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