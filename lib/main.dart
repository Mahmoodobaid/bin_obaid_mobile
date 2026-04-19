import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _clearOldSettings();
  await _requestAllPermissions();

  final hasInternet = await _checkInternet();
  if (!hasInternet) {
    runApp(const ProviderScope(child: NoInternetApp()));
    return;
  }

  try {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  } catch (_) {}
  try {
    await Hive.initFlutter();
  } catch (_) {}
  try {
    await LocalStorageService.init();
  } catch (_) {}
  try {
    await LocalNotificationService.initialize(navKey: navigatorKey);
  } catch (_) {}

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _clearOldSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('custom_supabase_url');
  await prefs.remove('custom_supabase_key');
}

Future<void> _requestAllPermissions() async {
  await Permission.storage.request();
  await Permission.location.request();
  await Permission.camera.request();
  await Permission.notification.request();
  // للتوافق مع أندرويد 13+
  if (await Permission.photos.isDenied) await Permission.photos.request();
}

Future<bool> _checkInternet() async {
  final connectivity = await Connectivity().checkConnectivity();
  return connectivity != ConnectivityResult.none;
}

class NoInternetApp extends StatelessWidget {
  const NoInternetApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off, size: 64), const SizedBox(height: 16),
      const Text('لا يوجد اتصال بالإنترنت'), const SizedBox(height: 24),
      ElevatedButton(onPressed: () => exit(0), child: const Text('إعادة المحاولة'))
    ]))),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'محلات بن عبيد',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(primaryColor: const Color(0xFF0F3BBF)),
      routerConfig: router,
    );
  }
}
