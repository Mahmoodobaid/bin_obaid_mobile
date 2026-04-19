import 'package:flutter/material.dart';
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

  // مسح الإعدادات المحفوظة القديمة (التي تحتوي على الرابط الخاطئ)
  await _clearOldSettings();

  // طلب الصلاحيات
  await _requestAllPermissions();

  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  await Hive.initFlutter();
  await LocalStorageService.init();
  await LocalNotificationService.initialize(navKey: navigatorKey);

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _clearOldSettings() async {
  final prefs = await SharedPreferences.getInstance();
  // حذف الإعدادات المخصصة القديمة
  await prefs.remove('custom_supabase_url');
  await prefs.remove('custom_supabase_key');
  await prefs.remove('custom_supabase_schema');
  await prefs.remove('custom_test_table');
}

Future<void> _requestAllPermissions() async {
  await Permission.storage.request();
  await Permission.location.request();
  await Permission.camera.request();
  await Permission.notification.request();
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'محلات بن عبيد التجارية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(primaryColor: const Color(0xFF0F3BBF)),
      routerConfig: router,
    );
  }
}
