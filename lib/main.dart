import 'services/permission_service.dart';
import 'package:flutter/material.dart'; import 'package:flutter_riverpod/flutter_riverpod.dart'; import 'package:supabase_flutter/supabase_flutter.dart'; import 'package:hive_flutter/hive_flutter.dart';
import 'app_router.dart'; import 'core/config/config.dart'; import 'services/local_notification_service.dart'; import 'services/local_storage_service.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async { WidgetsFlutterBinding.ensureInitialized(); await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey); await Hive.initFlutter(); await LocalStorageService.init(); await LocalNotificationService.initialize(navKey: navigatorKey); runApp(const ProviderScope(child: MyApp())); }
class MyApp extends ConsumerWidget { const MyApp({super.key}); @override Widget build(BuildContext context, WidgetRef ref) { final router = ref.watch(goRouterProvider); return MaterialApp.router(title: 'بن عبيد', theme: ThemeData.dark().copyWith(primaryColor: const Color(0xFF0F3BBF)), routerConfig: router, debugShowCheckedModeBanner: false); } }
