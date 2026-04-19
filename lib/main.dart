import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_router.dart';
import 'core/config/config.dart';
import 'services/local_notification_service.dart';
import 'services/local_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // طلب جميع الصلاحيات المطلوبة عند بدء التشغيل
  await _requestAllPermissions();

  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  await Hive.initFlutter();
  await LocalStorageService.init();
  await LocalNotificationService.initialize(navKey: navigatorKey);

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _requestAllPermissions() async {
  // قائمة الصلاحيات التي سيتم طلبها
  List<Permission> permissions = [
    Permission.storage,
    Permission.location,
    Permission.camera,
    Permission.notification,
    Permission.photos,
    Permission.manageExternalStorage,
  ];

  // طلب الصلاحيات التي لم تُمنح بعد
  for (var perm in permissions) {
    if (await perm.isDenied || await perm.isPermanentlyDenied) {
      await perm.request();
    }
  }
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
