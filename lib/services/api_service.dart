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
    },
    connectTimeout: const Duration(seconds: 15),
  ));

  void updateAuthToken(String t) {
    _dio.options.headers['Authorization'] = 'Bearer $t';
  }

  // ... (دوال المصادقة تبقى كما هي)

  Future<List<Product>> fetchProducts({
    required int page,
    required int pageSize,
    String? search,
    String? category,
  }) async {
    try {
      // استخدام استعلام بسيط مطابق لـ curl الناجح
      var query = _dio.get('/rest/v1/products');
      
      // نضيف المعاملات بشكل يدوي لضمان التوافق
      final params = <String, dynamic>{
        'select': '*',
        'limit': pageSize,
        'offset': (page - 1) * pageSize,
        'order': 'name.asc',
      };
      
      // نضيف البحث فقط إذا كان موجوداً
      if (search != null && search.isNotEmpty) {
        params['or'] = '(name.ilike.%$search%,sku.ilike.%$search%)';
      }
      
      // نضيف التصفية حسب الفئة
      if (category != null && category.isNotEmpty) {
        params['category'] = 'eq.$category';
      }

      final r = await _dio.get('/rest/v1/products', queryParameters: params);
      
      print('✅ عدد المنتجات المستلمة: ${r.data.length}');
      return (r.data as List).map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      print('❌ فشل جلب المنتجات: $e');
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
    } catch (e) {
      return [];
    }
  }

  Future<Product?> fetchProductBySku(String sku) async {
    try {
      final r = await _dio.get('/rest/v1/products', queryParameters: {'sku': 'eq.$sku'});
      if ((r.data as List).isNotEmpty) return Product.fromJson(r.data[0]);
    } catch (e) {}
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
      final categories = (r.data as List).map((e) => e['category'].toString()).toSet().toList();
      return categories;
    } catch (e) {
      return [];
    }
  }

  // ... (باقي الدوال كما هي دون تغيير)
}
