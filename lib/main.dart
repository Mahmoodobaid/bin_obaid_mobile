import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// استيراد ملفات مشروعك - تأكد من صحة المسارات لديك
import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 1. التأكد من تهيئة روابط Flutter مع النظام الأساسي
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ضبط اتجاه الشاشة (عمودي فقط لضمان استقرار الواجهة)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 3. تنظيف أي إعدادات قديمة قد تسبب تعارض
  await _clearOldSettings();

  // 4. نظام طلب الصلاحيات المتسلسل (Strict Permission Protocol)
  // يطلب الصلاحيات واحدة تلو الأخرى لضمان عدم تجاهل النظام لأي منها
  await _enforceAllPermissions();

  // 5. فحص حالة الاتصال بالإنترنت قبل التشغيل
  final bool hasInternet = await _checkInternetConnection();
  
  // 6. تهيئة الخدمات الأساسية مع نظام حماية من الانهيار (Safe Initialization)
  await _initializeCoreServices();

  // 7. تشغيل التطبيق بناءً على حالة الإنترنت
  if (!hasInternet) {
    runApp(const ProviderScope(child: NoInternetApp()));
  } else {
    runApp(const ProviderScope(child: MyApp()));
  }
}

/// دالة لتهيئة الخدمات الأساسية بأمان
Future<void> _initializeCoreServices() async {
  try {
    // تهيئة Supabase
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    // تهيئة التخزين المحلي (Hive)
    await Hive.initFlutter();
    
    // تهيئة خدماتنا الخاصة
    await LocalStorageService.init();
    await LocalNotificationService.initialize(navKey: navigatorKey);
    
    debugPrint("✅ تم تهيئة جميع الخدمات بنجاح");
  } catch (e) {
    debugPrint("❌ خطأ أثناء التهيئة: $e");
    // هنا النظام سيستمر في العمل ولن ينهار بفضل try-catch
  }
}

/// دالة لفرض طلب الصلاحيات بشكل متسلسل وصارم
Future<void> _enforceAllPermissions() async {
  List<Permission> permissionsList = [
    Permission.camera,
    Permission.location,
    Permission.notification,
    Permission.photos,
    Permission.storage,
  ];

  for (Permission perm in permissionsList) {
    final status = await perm.status;
    if (!status.isGranted) {
      await perm.request();
      // تأخير بسيط جداً لمنع تداخل نوافذ النظام
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // صلاحية إدارة الملفات الشاملة (لأنظمة أندرويد الحديثة)
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }
}

Future<void> _clearOldSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('custom_supabase_url');
  await prefs.remove('custom_supabase_key');
}

Future<bool> _checkInternetConnection() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.none) {
    return false;
  }
  return true;
}

/// واجهة احترافية عند انقطاع الإنترنت
class NoInternetApp extends StatelessWidget {
  const NoInternetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                'عذراً، لا يوجد اتصال بالإنترنت',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'يتطلب تطبيق بن عبيد الاتصال بالشبكة للمزامنة أول مرة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => exit(0),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'مؤسسة بن عبيد التجارية',
      debugShowCheckedModeBanner: false,
      // ثيم احترافي غامق (Dark Theme) كما تفضل
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F3BBF),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      routerConfig: router,
    );
  }
}
