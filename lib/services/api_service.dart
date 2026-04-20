import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/config.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  static const String baseUrl = AppConfig.supabaseUrl;
  static const String anonKey = AppConfig.supabaseAnonKey;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
      'Content-Type': 'application/json',
     'Prefer': 'return=minimal',
 
    },
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  void updateAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ---------- المصادقة ----------
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

  // ---------- المنتجات ----------
  Future<List<Product>> fetchProducts({
    required int page,
    required int pageSize,
    String? search,
    String? category,
  }) async {
    try {
      final query = StringBuffer('/rest/v1/products?select=*');
      if (search != null && search.isNotEmpty) {
        query.write('&or=(name.ilike.%25${Uri.encodeComponent(search)}%25,sku.ilike.%25${Uri.encodeComponent(search)}%25)');
      }
      if (category != null && category.isNotEmpty) {
        query.write('&category=eq.${Uri.encodeComponent(category)}');
      }
      query.write('&limit=$pageSize&offset=${(page - 1) * pageSize}&order=name.asc');
      final r = await _dio.get(query.toString());
      return (r.data as List).map((e) => Product.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Product>> searchProducts({required String query, int limit = 20}) async {
    try {
      final r = await _dio.get('/rest/v1/products', queryParameters: {
        'select': '*',
        'or': '(name.ilike.%$query%,sku.ilike.%$query%)',
        'limit': limit,
        'order': 'name.asc',
      });
      return (r.data as List).map((e) => Product.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Product?> fetchProductBySku(String sku) async {
    try {
      print('🔍 البحث عن منتج بـ SKU: "$sku"');
      final r = await _dio.get('/rest/v1/products', queryParameters: {
        'sku': 'ilike.$sku', // استخدام ilike للتسامح مع حالة الأحرف
        'limit': 1,
      });
      if ((r.data as List).isNotEmpty) {
        print('✅ تم العثور على المنتج: ${r.data[0]['name']}');
        return Product.fromJson(r.data[0]);
      } else {
        print('❌ لم يتم العثور على منتج بـ SKU: $sku');
      }
    } catch (e) {
      print('❌ خطأ في fetchProductBySku: $e');
    }
    return null;
  }

  Future<void> importProductsBatch(List<Map<String, dynamic>> items) async {
    await _dio.post('/rest/v1/products', data: items);
  }

  Future<Map<String, dynamic>> syncProducts(List<Map<String, String>> localProductsMeta) async {
    return {'updated': [], 'deleted': []};
  }

  Future<List<String>> fetchCategories() async {
    try {
      final r = await _dio.get('/rest/v1/products', queryParameters: {'select': 'category'});
      return (r.data as List).map((e) => e['category'].toString()).toSet().toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- طلبات المدير ----------
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    try {
      final r = await _dio.get('/rest/v1/pending_users', queryParameters: {'status': 'eq.pending'});
      return List<Map<String, dynamic>>.from(r.data);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPasswordResetRequests() async {
    try {
      final r = await _dio.get('/rest/v1/password_reset_requests', queryParameters: {'status': 'eq.pending'});
      return List<Map<String, dynamic>>.from(r.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> updatePendingUserStatus(String id, String status, {String? rejectReason}) async {
    final data = {'status': status};
    if (rejectReason != null) data['reject_reason'] = rejectReason;
    await _dio.patch('/rest/v1/pending_users?id=eq.$id', data: data);
  }

  Future<void> createUserAccount({required String phone, required String fullName, required String role, required String password}) async {
    await _dio.post('/rest/v1/users', data: {
      'phone': phone,
      'full_name': fullName,
      'role': role,
      'password_hash': password,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updatePasswordResetRequest(String id, String status) async {
    await _dio.patch('/rest/v1/password_reset_requests?id=eq.$id', data: {'status': status});
  }

  // ---------- الفواتير ----------
  Future<void> createInvoice(Map<String, dynamic> data) async {
    await _dio.post('/rest/v1/invoices', data: data);
  }

  // ---------- النماذج ----------
  Future<Map<String, dynamic>> fetchTemplate(int id) async {
    final r = await _dio.get('/rest/v1/templates', queryParameters: {'id': 'eq.$id'});
    final data = r.data[0];
    final itemsResp = await _dio.get('/rest/v1/template_items', queryParameters: {'template_id': 'eq.$id'});
    data['items'] = itemsResp.data;
    return data;
  }

  Future<List<Map<String, dynamic>>> fetchTemplates() async {
    final r = await _dio.get('/rest/v1/templates');
    return List<Map<String, dynamic>>.from(r.data);
  }

  // ---------- إدارة قاعدة البيانات ----------
  Future<List<String>> getTables() async {
    return ['users', 'pending_users', 'products', 'invoices', 'invoice_items', 'templates', 'template_items', 'password_reset_requests', 'fcm_tokens', 'settings'];
  }

  Future<List<Map<String, dynamic>>> getTableColumns(String table) async {
    return [{'column_name': 'id', 'data_type': 'uuid', 'is_nullable': 'NO'}, {'column_name': 'created_at', 'data_type': 'timestamp', 'is_nullable': 'YES'}];
  }

  Future<List<Map<String, dynamic>>> getTableData(String table, {int limit = 50}) async {
    try {
      final r = await _dio.get('/rest/v1/$table', queryParameters: {'limit': limit});
      return List<Map<String, dynamic>>.from(r.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> insertRecord(String table, Map<String, dynamic> data) async {
    await _dio.post('/rest/v1/$table', data: data);
  }

  Future<void> updateRecord(String table, Map<String, dynamic> oldRecord, Map<String, dynamic> newData) async {
    final id = oldRecord['id'] ?? oldRecord['sku'];
    if (id != null) await _dio.patch('/rest/v1/$table?id=eq.$id', data: newData);
  }

  Future<void> deleteRecord(String table, Map<String, dynamic> record) async {
    final id = record['id'] ?? record['sku'];
    if (id != null) await _dio.delete('/rest/v1/$table?id=eq.$id');
  }

  // ---------- إدارة الإشعارات ----------
  Future<List<Map<String, dynamic>>> getFcmTokens() async {
    try {
      final r = await _dio.get('/rest/v1/fcm_tokens', queryParameters: {'select': '*, users(full_name, phone)'});
      return List<Map<String, dynamic>>.from(r.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteFcmToken(int id) async {
    await _dio.delete('/rest/v1/fcm_tokens', queryParameters: {'id': 'eq.$id'});
  }

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final r = await _dio.get('/rest/v1/settings');
      final Map<String, dynamic> settings = {};
      for (var item in r.data) {
        settings[item['key']] = item['value'];
      }
      return settings;
    } catch (_) {
      return {};
    }
  }

  Future<void> updateSetting(String key, String value) async {
    try {
      await _dio.post('/rest/v1/settings', data: {'key': key, 'value': value});
    } catch (_) {
      await _dio.patch('/rest/v1/settings', queryParameters: {'key': 'eq.$key'}, data: {'value': value});
    }
  }

  Future<void> sendPushNotification({required String title, required String body, String? userId}) async {
    await _dio.post('/api/send-notification', data: {'title': title, 'body': body, 'user_id': userId});
  }

  // ---------- الملف الشخصي ----------
  Future<void> updateUserProfile({String? fullName, String? avatarUrl}) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    await _dio.patch('/rest/v1/users', data: data);
  }

  Future<void> changePassword(String newPassword) async {
    await _dio.post('/auth/v1/user/password', data: {'password': newPassword});
  }

  // ---------- المندوب ----------
  Future<List<Map<String, dynamic>>> getDeliveryOrders() async {
    try {
      final r = await _dio.get('/rest/v1/invoices', queryParameters: {'status': 'in.(pending,assigned,picked_up)', 'order': 'created_at.desc'});
      return List<Map<String, dynamic>>.from(r.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _dio.patch('/rest/v1/invoices', queryParameters: {'id': 'eq.$orderId'}, data: {'status': status});
  }

  // ---------- الإحصائيات ----------
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final r1 = await _dio.get('/rest/v1/invoices', queryParameters: {'select': 'count'});
      final r2 = await _dio.get('/rest/v1/invoices', queryParameters: {'select': 'sum(total_amount)'});
      final r3 = await _dio.get('/rest/v1/invoices', queryParameters: {'select': 'count', 'created_at': 'gte.${DateTime.now().subtract(const Duration(days: 1)).toIso8601String()}'});
      final r4 = await _dio.get('/rest/v1/products', queryParameters: {'select': 'sum(stock_quantity)'});
      return {
        'newOrders': r1.data[0]['count'] ?? 0,
        'totalSales': (r2.data[0]['sum'] ?? 0.0).toDouble(),
        'dailyInvoices': r3.data[0]['count'] ?? 0,
        'availableProducts': r4.data[0]['sum'] ?? 0,
      };
    } catch (_) {
      return {'newOrders': 0, 'totalSales': 0.0, 'dailyInvoices': 0, 'availableProducts': 0};
    }
  }
}
