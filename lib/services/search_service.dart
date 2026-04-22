// search_service.dart
// خدمة بحث احترافية وكاملة مع:
// - تطبيع متقدم للنصوص العربية والأرقام
// - بحث Fuzzy (Levenshtein) مع ترتيب حسب الصلة
// - دعم البحث غير المرتب (unordered)
// - فهرسة باستخدام searchTokens من Product
// - ذاكرة مؤقتة ذكية مع TTL
// - Debounce متغير حسب طول النص
// - البحث المحلي أولاً (Hive) ثم عن بعد (Supabase)
// - تحديث الخلفية للنتائج من الخادم
// - استخدام Isolate (compute) للمعالجات الثقيلة
// - دعم الأخطاء الإملائية والتشكيل

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/product_model.dart';
import 'api_service.dart'; // افترض وجود ApiService للتواصل مع Supabase

class SearchService {
  final ApiService _api;
  static const String _productsBox = 'products_box';
  static const int _defaultLimit = 20;
  static const int _cacheTtlSeconds = 300; // 5 دقائق
  static const int _minQueryLength = 2;

  // الذاكرة المؤقتة للنتائج
  final Map<String, _CachedResult> _cache = {};

  // متغيرات الـ Debounce
  Timer? _debounceTimer;

  // حالة الاتصال
  bool _isOffline = false;
  final Connectivity _connectivity = Connectivity();

  // منع تكرار العمليات المتزامنة
  final Set<String> _pendingRemoteQueries = {};

  SearchService(this._api) {
    _initConnectivity();
  }

  // ============================================================
  // 1. إدارة الاتصال بالإنترنت
  // ============================================================
  void _initConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      final newOffline = result == ConnectivityResult.none;
      if (_isOffline != newOffline) {
        _isOffline = newOffline;
        if (!_isOffline) {
          // عند عودة الإنترنت، نمسح الكاش لضمان تحديث البيانات
          _cache.clear();
        }
      }
    });
    _connectivity.checkConnectivity().then((result) {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  bool get isOffline => _isOffline;

  // ============================================================
  // 2. الواجهة الرئيسية للبحث (مع Debounce)
  // ============================================================
  /// بحث مع Debounce - مناسب للإدخال المباشر من المستخدم
  void debounceSearch(
    String query,
    Function(List<Product>) onResults, {
    int limit = _defaultLimit,
  }) {
    _debounceTimer?.cancel();
    final delay = _getDebounceDelay(query);
    _debounceTimer = Timer(Duration(milliseconds: delay), () async {
      final results = await search(query, limit: limit);
      onResults(results);
    });
  }

  /// البحث الرئيسي - يستخدم الكاش أولاً، ثم محلي، ثم عن بعد
  Future<List<Product>> search(String query, {int limit = _defaultLimit}) async {
    final normalized = _normalizeText(query);
    if (normalized.length < _minQueryLength) return [];

    // 1. التحقق من الكاش
    final cached = _getFromCache(normalized);
    if (cached != null) {
      return cached.take(limit).toList();
    }

    // 2. البحث المحلي (Hive) – سريع جداً
    final localResults = await _searchLocal(normalized, limit: limit);

    // 3. إذا كان هناك اتصال، نبدأ بحثاً عن بعد في الخلفية ونحدث المحلي
    if (!_isOffline && !_pendingRemoteQueries.contains(normalized)) {
      _pendingRemoteQueries.add(normalized);
      // البحث عن بعد في الخلفية (لا ننتظره)
      _searchRemoteAndUpdateLocal(normalized, limit: limit).then((_) {
        _pendingRemoteQueries.remove(normalized);
      });
    }

    // 4. نعيد النتائج المحلية فوراً (تجربة سريعة)
    if (localResults.isNotEmpty) {
      _updateCache(normalized, localResults);
      return localResults.take(limit).toList();
    }

    // 5. إذا لم توجد نتائج محلية وكان هناك اتصال، ننتظر النتائج من الخادم
    if (!_isOffline) {
      final remoteResults = await _searchRemote(normalized, limit: limit);
      _updateCache(normalized, remoteResults);
      return remoteResults.take(limit).toList();
    }

    return [];
  }

  // ============================================================
  // 3. البحث المحلي المتقدم (Hive + Fuzzy)
  // ============================================================
  Future<List<Product>> _searchLocal(String normalizedQuery, {int limit = _defaultLimit}) async {
    try {
      final box = await Hive.openBox<Product>(_productsBox);
      final allProducts = box.values.toList();

      // استخدام Isolate إذا كان العدد كبيراً
      if (allProducts.length > 500) {
        return await compute(_searchLocalIsolate, _SearchParams(allProducts, normalizedQuery, limit));
      } else {
        return _performLocalSearch(allProducts, normalizedQuery, limit);
      }
    } catch (e) {
      debugPrint('خطأ في البحث المحلي: $e');
      return [];
    }
  }

  // المعالجة في Isolate (للأعداد الكبيرة)
  static List<Product> _searchLocalIsolate(_SearchParams params) {
    return _performLocalSearchStatic(params.products, params.query, params.limit);
  }

  static List<Product> _performLocalSearchStatic(List<Product> products, String query, int limit) {
    final queryTokens = query.split(' ').where((t) => t.isNotEmpty).toList();
    final scores = <Product, double>{};

    for (final product in products) {
      // استخدام searchTokens إن وجد، وإلا نستخدم الحقول الأساسية
      final searchableText = product.searchTokens ?? _generateSearchableText(product);
      final score = _calculateRelevanceScore(searchableText, queryTokens);
      if (score > 0.1) {
        scores[product] = score;
      }
    }

    final sorted = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return sorted.take(limit).toList();
  }

  List<Product> _performLocalSearch(List<Product> products, String query, int limit) {
    final queryTokens = query.split(' ').where((t) => t.isNotEmpty).toList();
    final scores = <Product, double>{};

    for (final product in products) {
      final searchableText = product.searchTokens ?? _generateSearchableText(product);
      final score = _calculateRelevanceScore(searchableText, queryTokens);
      if (score > 0.1) {
        scores[product] = score;
      }
    }

    final sorted = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return sorted.take(limit).toList();
  }

  String _generateSearchableText(Product product) {
    return '${product.name} ${product.sku} ${product.barcode ?? ''} ${product.category ?? ''} ${product.description ?? ''}'
        .toLowerCase();
  }

  // ============================================================
  // 4. حساب درجة الصلة (Fuzzy + Token Set Ratio)
  // ============================================================
  static double _calculateRelevanceScore(String text, List<String> queryTokens) {
    if (queryTokens.isEmpty) return 0.0;
    final textTokens = text.split(' ').toSet();
    double totalScore = 0.0;

    for (final qToken in queryTokens) {
      double bestMatch = 0.0;
      for (final tToken in textTokens) {
        // تطابق تام
        if (tToken == qToken) {
          bestMatch = 1.0;
          break;
        }
        // تطابق جزئي
        if (tToken.contains(qToken) || qToken.contains(tToken)) {
          bestMatch = max(bestMatch, 0.8);
        }
        // تشابه Levenshtein (إذا كانت المسافة <= 2)
        final distance = _levenshteinDistance(tToken, qToken);
        if (distance <= 2) {
          bestMatch = max(bestMatch, 0.7 - (distance / 10.0));
        }
      }
      totalScore += bestMatch;
    }
    return totalScore / queryTokens.length;
  }

  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final matrix = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= b.length; j++) matrix[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return matrix[a.length][b.length];
  }

  // ============================================================
  // 5. البحث عن بعد (Supabase)
  // ============================================================
  Future<List<Product>> _searchRemote(String normalizedQuery, {int limit = _defaultLimit}) async {
    try {
      // استخدام ApiService الموجود
      final results = await _api.searchProducts(query: normalizedQuery, limit: limit);
      return results;
    } catch (e) {
      debugPrint('فشل البحث عن بعد: $e');
      return [];
    }
  }

  Future<void> _searchRemoteAndUpdateLocal(String normalizedQuery, {int limit = _defaultLimit}) async {
    try {
      final remoteResults = await _api.searchProducts(query: normalizedQuery, limit: limit);
      if (remoteResults.isNotEmpty) {
        await _updateLocalProducts(remoteResults);
        // تحديث الكاش بالنتائج الجديدة
        _updateCache(normalizedQuery, remoteResults);
      }
    } catch (e) {
      debugPrint('فشل تحديث الخلفية: $e');
    }
  }

  /// تحديث أو إضافة المنتجات في Hive (فقط المنتجات التي تم جلبها)
  Future<void> _updateLocalProducts(List<Product> products) async {
    if (products.isEmpty) return;
    final box = await Hive.openBox<Product>(_productsBox);
    for (final product in products) {
      final existing = box.get(product.sku);
      if (existing == null || existing.updatedAt.isBefore(product.updatedAt)) {
        await box.put(product.sku, product);
      }
    }
  }

  // ============================================================
  // 6. الذاكرة المؤقتة (Cache)
  // ============================================================
  List<Product>? _getFromCache(String query) {
    final cached = _cache[query];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }
    _cache.remove(query);
    return null;
  }

  void _updateCache(String query, List<Product> results) {
    _cache[query] = _CachedResult(results);
  }

  // ============================================================
  // 7. تطبيع النص المتقدم (مع دعم العربية والأرقام والتشكيل)
  // ============================================================
  static String _normalizeText(String input) {
    if (input.isEmpty) return '';
    String normalized = input;

    // توحيد الألف والهمزة
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    // توحيد التاء المربوطة والهاء
    normalized = normalized.replaceAll('ة', 'ه');
    // إزالة التشكيل (الحركات)
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

  // ============================================================
  // 8. تحديد زمن Debounce حسب طول النص
  // ============================================================
  int _getDebounceDelay(String query) {
    final len = query.trim().length;
    if (len < 3) return 500;
    if (len < 6) return 300;
    return 200;
  }

  // ============================================================
  // 9. تنظيف الموارد
  // ============================================================
  void dispose() {
    _debounceTimer?.cancel();
    _cache.clear();
  }
}

// ============================================================
// فئات مساعدة
// ============================================================
class _CachedResult {
  final List<Product> results;
  final DateTime timestamp;

  _CachedResult(this.results) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > _cacheTtlSeconds;
}

class _SearchParams {
  final List<Product> products;
  final String query;
  final int limit;

  _SearchParams(this.products, this.query, this.limit);
}

// تصدير الثوابت للاستخدام الخارجي إذا احتاجها أحد
const int searchDefaultLimit = 20;
const int searchMinQueryLength = 2;