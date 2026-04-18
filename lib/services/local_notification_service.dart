import 'package:flutter/material.dart'; import 'package:flutter_local_notifications/flutter_local_notifications.dart'; import 'package:go_router/go_router.dart';
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? navigatorKey;
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async { navigatorKey = navKey; const android = AndroidInitializationSettings('@mipmap/ic_launcher'); const ios = DarwinInitializationSettings(); const settings = InitializationSettings(android: android, iOS: ios); await _notifications.initialize(settings, onDidReceiveNotificationResponse: _onTap); }
  static void _onTap(NotificationResponse r) { if(r.payload!=null && navigatorKey?.currentContext!=null) { final ctx = navigatorKey!.currentContext!; if(r.payload=='admin_pending') ctx.push('/admin'); } }
  static Future<void> show({required int id, required String title, required String body, String? payload}) async { const android = AndroidNotificationDetails('channel', 'عام', importance: Importance.high); const ios = DarwinNotificationDetails(); const details = NotificationDetails(android: android, iOS: ios); await _notifications.show(id, title, body, details, payload: payload); }
}
