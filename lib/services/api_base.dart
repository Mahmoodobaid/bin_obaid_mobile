import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/config/config.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';

class ApiBase {
  static const String baseUrl = AppConfig.supabaseUrl;
  static const String anonKey = AppConfig.supabaseAnonKey;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
      'Content-Type': 'application/json',
    },
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Dio get dio => _dio;

  void updateAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // الدوال الأساسية التي لا تتغير كثيرًا
  Future<bool> checkPhoneExists(String phone) async {
    try {
      final r = await _dio.get('/rest/v1/users', queryParameters: {'phone': 'eq.$phone', 'select': 'phone'});
      return (r.data as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkPendingPhoneExists(String phone) async {
    try {
      final r = await _dio.get('/rest/v1/pending_users', queryParameters: {'phone': 'eq.$phone', 'select': 'phone'});
      return (r.data as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> loginWithPhone(String phone, String password) async {
    try {
      final email = '$phone@binobaid.com';
      final r = await _dio.post('/auth/v1/token?grant_type=password', data: {'email': email, 'password': password});
      if (r.statusCode == 200) {
        final data = r.data;
        updateAuthToken(data['access_token']);
        final userData = await _dio.get('/rest/v1/users', queryParameters: {'phone': 'eq.$phone'});
        if ((userData.data as List).isNotEmpty) {
          return {...userData.data[0], 'access_token': data['access_token']};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> submitRegistrationRequest({
    required String phone,
    required String fullName,
    required String occupation,
    required String address,
    String? imageBase64,
  }) async {
    try {
      final data = {
        'phone': phone,
        'full_name': fullName,
        'occupation': occupation,
        'address': address,
        'image_url': imageBase64,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };
      await _dio.post('/rest/v1/pending_users', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addPasswordResetRequest(String phone) async {
    try {
      await _dio.post('/rest/v1/password_reset_requests', data: {
        'phone': phone,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
