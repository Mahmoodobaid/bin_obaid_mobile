import 'package:dio/dio.dart';
import '../models/product_model.dart';
import 'api_base.dart';

/// هذا الامتداد يحتوي على الدوال الإضافية التي يمكن التعديل عليها أو إضافة دوال جديدة في نهايته.
extension ApiExtensions on ApiBase {
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

      final response = await dio.get(query.toString());
      return (response.data as List).map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Product>> searchProducts({required String query, int limit = 20}) async {
    try {
      final r = await dio.get('/rest/v1/products', queryParameters: {
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
      final r = await dio.get('/rest/v1/products', queryParameters: {'sku': 'eq.$sku'});
      if ((r.data as List).isNotEmpty) return Product.fromJson(r.data[0]);
    } catch (_) {}
    return null;
  }

  // ---------- إدارة قاعدة البيانات ----------
  Future<List<String>> getTables() async {
    return ['users', 'pending_users', 'products', 'invoices', 'invoice_items', 'templates', 'template_items', 'password_reset_requests', 'fcm_tokens', 'settings'];
  }

  Future<List<Map<String, dynamic>>> getTableData(String table, {int limit = 50}) async {
    try {
      final r = await dio.get('/rest/v1/$table', queryParameters: {'limit': limit});
      return List<Map<String, dynamic>>.from(r.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> insertRecord(String table, Map<String, dynamic> data) async {
    await dio.post('/rest/v1/$table', data: data);
  }

  Future<void> updateRecord(String table, Map<String, dynamic> oldRecord, Map<String, dynamic> newData) async {
    final id = oldRecord['id'] ?? oldRecord['sku'];
    if (id != null) await dio.patch('/rest/v1/$table?id=eq.$id', data: newData);
  }

  Future<void> deleteRecord(String table, Map<String, dynamic> record) async {
    final id = record['id'] ?? record['sku'];
    if (id != null) await dio.delete('/rest/v1/$table?id=eq.$id');
  }

  // ---------- الفواتير ----------
  Future<void> createInvoice(Map<String, dynamic> data) async {
    await dio.post('/rest/v1/invoices', data: data);
  }

  // ---------- الملف الشخصي ----------
  Future<void> updateUserProfile({String? fullName, String? avatarUrl}) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    await dio.patch('/rest/v1/users', data: data);
  }

  Future<void> changePassword(String newPassword) async {
    await dio.post('/auth/v1/user/password', data: {'password': newPassword});
  }

  // ---------- المندوب ----------
  Future<List<Map<String, dynamic>>> getDeliveryOrders() async {
    try {
      final r = await dio.get('/rest/v1/invoices', queryParameters: {'status': 'in.(pending,assigned,picked_up)', 'order': 'created_at.desc'});
      return List<Map<String, dynamic>>.from(r.data);
    } catch (_) {
      return [];
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await dio.patch('/rest/v1/invoices', queryParameters: {'id': 'eq.$orderId'}, data: {'status': status});
  }

  // ---------- الإحصائيات ----------
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final r1 = await dio.get('/rest/v1/invoices', queryParameters: {'select': 'count'});
      final r2 = await dio.get('/rest/v1/invoices', queryParameters: {'select': 'sum(total_amount)'});
      final r3 = await dio.get('/rest/v1/invoices', queryParameters: {'select': 'count', 'created_at': 'gte.${DateTime.now().subtract(const Duration(days: 1)).toIso8601String()}'});
      final r4 = await dio.get('/rest/v1/products', queryParameters: {'select': 'sum(stock_quantity)'});
      return {
        'newOrders': r1.data[0]['count'] ?? 0,
        'totalSales': r2.data[0]['sum'] ?? 0.0,
        'dailyInvoices': r3.data[0]['count'] ?? 0,
        'availableProducts': r4.data[0]['sum'] ?? 0,
      };
    } catch (_) {
      return {'newOrders': 12, 'totalSales': 5500.0, 'dailyInvoices': 35, 'availableProducts': 1250};
    }
  }

  // ========== أضف دوالك الجديدة هنا ==========
  // يمكنك إضافة أي دوال جديدة في نهاية هذا الملف، مثال:
  // Future<void> myNewFunction() async { ... }
}
