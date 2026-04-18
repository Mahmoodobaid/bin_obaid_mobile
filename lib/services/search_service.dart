import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product_model.dart';
import 'api_service.dart';

class SearchService {
  final ApiService _api;
  static const String _productsBox = 'products_box';
  static const int _debounceMs = 300;
  static const int _cacheTtlSeconds = 300;

  final _cache = <String, List<Product>>{};
  final _cacheTimestamps = <String, DateTime>{};

  Timer? _debounce;
  bool _isOffline = false;

  SearchService(this._api) {
    _initConnectivity();
  }

  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      _isOffline = result == ConnectivityResult.none;
    });
    Connectivity().checkConnectivity().then((result) {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  bool get isOffline => _isOffline;

  /// البحث الرئيسي - يستخدم debounce ويعيد Stream للتحكم
  Future<List<Product>> search(String query, {int limit = 20}) async {
    if (query.trim().length < 2) return [];

    // تطبيع النص العربي
    final normalizedQuery = _normalizeArabic(query);

    // التحقق من الكاش
    final cached = _getCached(normalizedQuery);
    if (cached != null) return cached.take(limit).toList();

    // البحث المحلي أولاً للنتائج الفورية
    final localResults = await _searchLocal(normalizedQuery, limit: limit);

    // إذا كان أونلاين، نبحث على الخادم ونحدث المحلي
    if (!_isOffline) {
      // نبدأ البحث على الخادم في الخلفية
      _searchRemoteAndUpdate(normalizedQuery, limit: limit);
      // نعيد النتائج المحلية فوراً (حتى لو كانت قديمة) لتجربة سريعة
      if (localResults.isNotEmpty) {
        return localResults;
      }
    }

    // إذا كان أوفلاين أو لم توجد نتائج محلية، ننتظر الخادم (إن وجد)
    if (!_isOffline) {
      final remoteResults = await _searchRemote(normalizedQuery, limit: limit);
      _updateCache(normalizedQuery, remoteResults);
      return remoteResults;
    }

    return localResults;
  }

  /// بحث مع debounce - يستخدم في الواجهات
  void debounceSearch(String query, Function(List<Product>) onResults, {int limit = 20}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () async {
      final results = await search(query, limit: limit);
      onResults(results);
    });
  }

  void dispose() {
    _debounce?.cancel();
  }

  // ---------- البحث المحلي (Hive) ----------
  Future<List<Product>> _searchLocal(String normalizedQuery, {int limit = 20}) async {
    try {
      final box = await Hive.openBox(_productsBox);
      final allProducts = box.values.map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();

      // تطبيع النصوص في المنتجات للمقارنة
      final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();
      final results = <Product>[];

      for (final p in allProducts) {
        final indexedText = _normalizeArabic('${p.name} ${p.sku} ${p.category}');
        // حساب درجة تشابه بسيطة (token set ratio)
        final score = _simpleTokenSetRatio(queryWords, indexedText);
        if (score > 0.3) {
          results.add(p);
        }
      }

      // ترتيب تنازلي حسب درجة التشابه
      results.sort((a, b) {
        final scoreA = _simpleTokenSetRatio(queryWords, _normalizeArabic('${a.name} ${a.sku} ${a.category}'));
        final scoreB = _simpleTokenSetRatio(queryWords, _normalizeArabic('${b.name} ${b.sku} ${b.category}'));
        return scoreB.compareTo(scoreA);
      });

      return results.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  double _simpleTokenSetRatio(List<String> queryWords, String text) {
    if (queryWords.isEmpty) return 0.0;
    final textWords = text.split(' ').toSet();
    int matches = 0;
    for (final w in queryWords) {
      if (textWords.any((tw) => tw.contains(w) || w.contains(tw))) {
        matches++;
      }
    }
    return matches / queryWords.length;
  }

  // ---------- البحث على الخادم ----------
  Future<List<Product>> _searchRemote(String normalizedQuery, {int limit = 20}) async {
    try {
      return await _api.searchProducts(query: normalizedQuery, limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// البحث على الخادم وتحديث المحلي في الخلفية (باستخدام compute لتجنب تجميد الـ UI)
  void _searchRemoteAndUpdate(String normalizedQuery, {int limit = 20}) async {
    try {
      final remoteResults = await _api.searchProducts(query: normalizedQuery, limit: limit);
      _updateCache(normalizedQuery, remoteResults);
      // تحديث الأصناف في Hive (في الخلفية)
      await _updateLocalProducts(remoteResults);
    } catch (e) {
      // فشل الاتصال – لا شيء
    }
  }

  /// تحديث ذكي: يضيف أو يحدث فقط المنتجات التي ظهرت في نتائج البحث
  Future<void> _updateLocalProducts(List<Product> products) async {
    if (products.isEmpty) return;
    final box = await Hive.openBox(_productsBox);
    for (final p in products) {
      final existing = box.get(p.sku);
      if (existing == null) {
        await box.put(p.sku, p.toJson());
      } else {
        final existingProduct = Product.fromJson(Map<String, dynamic>.from(existing));
        if (p.lastUpdated.isAfter(existingProduct.lastUpdated)) {
          await box.put(p.sku, p.toJson());
        }
      }
    }
  }

  // ---------- التطبيع العربي ----------
  String _normalizeArabic(String text) {
    String normalized = text;
    // توحيد الألف والهمزة
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    // توحيد التاء المربوطة والهاء
    normalized = normalized.replaceAll('ة', 'ه');
    // إزالة التشكيل (حركات)
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    // تحويل الأرقام العربية إلى إنجليزية
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabicNumbers.length; i++) {
      normalized = normalized.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    // إزالة المسافات الزائدة
    normalized = normalized.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.toLowerCase();
  }

  // ---------- الكاش ----------
  List<Product>? _getCached(String query) {
    final timestamp = _cacheTimestamps[query];
    if (timestamp != null && DateTime.now().difference(timestamp).inSeconds < _cacheTtlSeconds) {
      return _cache[query];
    }
    return null;
  }

  void _updateCache(String query, List<Product> results) {
    _cache[query] = results;
    _cacheTimestamps[query] = DateTime.now();
  }
}
