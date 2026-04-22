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
// search_service.dart
// خدمة بحث احترافية - نسخة خالية من الأخطاء
// تم إضافة الدالة _generateSearchableText والثابت _cacheTtlSeconds

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/product_model.dart';
import 'api_service.dart';

class SearchService {
  final ApiService _api;
  static const String _productsBox = 'products_box';
  static const int _defaultLimit = 20;
  static const int _cacheTtlSeconds = 300; // 5 دقائق
  static const int _minQueryLength = 2;

  final Map<String, _CachedResult> _cache = {};
  Timer? _debounceTimer;
  bool _isOffline = false;
  final Connectivity _connectivity = Connectivity();
  final Set<String> _pendingRemoteQueries = {};

  SearchService(this._api) {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      final newOffline = result == ConnectivityResult.none;
      if (_isOffline != newOffline) {
        _isOffline = newOffline;
        if (!_isOffline) _cache.clear();
      }
    });
    _connectivity.checkConnectivity().then((result) {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  bool get isOffline => _isOffline;

  void debounceSearch(String query, Function(List<Product>) onResults, {int limit = _defaultLimit}) {
    _debounceTimer?.cancel();
    final delay = query.length < 3 ? 500 : 200;
    _debounceTimer = Timer(Duration(milliseconds: delay), () async {
      final results = await search(query, limit: limit);
      onResults(results);
    });
  }

  Future<List<Product>> search(String query, {int limit = _defaultLimit}) async {
    final normalized = _normalizeText(query);
    if (normalized.length < _minQueryLength) return [];

    final cached = _getFromCache(normalized);
    if (cached != null) return cached.take(limit).toList();

    final localResults = await _searchLocal(normalized, limit: limit);
    if (!_isOffline && !_pendingRemoteQueries.contains(normalized)) {
      _pendingRemoteQueries.add(normalized);
      _searchRemoteAndUpdateLocal(normalized, limit: limit).then((_) {
        _pendingRemoteQueries.remove(normalized);
      });
    }
    if (localResults.isNotEmpty) {
      _updateCache(normalized, localResults);
      return localResults.take(limit).toList();
    }
    if (!_isOffline) {
      final remoteResults = await _searchRemote(normalized, limit: limit);
      _updateCache(normalized, remoteResults);
      return remoteResults.take(limit).toList();
    }
    return [];
  }

  Future<List<Product>> _searchLocal(String normalizedQuery, {int limit = _defaultLimit}) async {
    try {
      final box = await Hive.openBox<Product>(_productsBox);
      final allProducts = box.values.toList();
      if (allProducts.length > 500) {
        return await compute(_searchLocalIsolate, _SearchParams(allProducts, normalizedQuery, limit));
      } else {
        return _performLocalSearch(allProducts, normalizedQuery, limit);
      }
    } catch (e) {
      debugPrint('Local search error: $e');
      return [];
    }
  }

  static List<Product> _searchLocalIsolate(_SearchParams params) {
    return _performLocalSearchStatic(params.products, params.query, params.limit);
  }

  static List<Product> _performLocalSearchStatic(List<Product> products, String query, int limit) {
    final queryTokens = query.split(' ').where((t) => t.isNotEmpty).toList();
    final scores = <Product, double>{};
    for (final product in products) {
      final searchableText = product.searchTokens ?? _generateSearchableTextStatic(product);
      final score = _calculateRelevanceScoreStatic(searchableText, queryTokens);
      if (score > 0.1) scores[product] = score;
    }
    final sorted = scores.keys.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return sorted.take(limit).toList();
  }

  List<Product> _performLocalSearch(List<Product> products, String query, int limit) {
    final queryTokens = query.split(' ').where((t) => t.isNotEmpty).toList();
    final scores = <Product, double>{};
    for (final product in products) {
      final searchableText = product.searchTokens ?? _generateSearchableText(product);
      final score = _calculateRelevanceScore(searchableText, queryTokens);
      if (score > 0.1) scores[product] = score;
    }
    final sorted = scores.keys.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return sorted.take(limit).toList();
  }

  String _generateSearchableText(Product product) {
    return '${product.name} ${product.sku} ${product.barcode ?? ''} ${product.category ?? ''} ${product.description ?? ''}'.toLowerCase();
  }

  static String _generateSearchableTextStatic(Product product) {
    return '${product.name} ${product.sku} ${product.barcode ?? ''} ${product.category ?? ''} ${product.description ?? ''}'.toLowerCase();
  }

  double _calculateRelevanceScore(String text, List<String> queryTokens) {
    if (queryTokens.isEmpty) return 0.0;
    final textTokens = text.split(' ').toSet();
    double totalScore = 0.0;
    for (final qToken in queryTokens) {
      double bestMatch = 0.0;
      for (final tToken in textTokens) {
        if (tToken == qToken) { bestMatch = 1.0; break; }
        if (tToken.contains(qToken) || qToken.contains(tToken)) bestMatch = max(bestMatch, 0.8);
        final distance = _levenshteinDistance(tToken, qToken);
        if (distance <= 2) bestMatch = max(bestMatch, 0.7 - (distance / 10.0));
      }
      totalScore += bestMatch;
    }
    return totalScore / queryTokens.length;
  }

  static double _calculateRelevanceScoreStatic(String text, List<String> queryTokens) {
    if (queryTokens.isEmpty) return 0.0;
    final textTokens = text.split(' ').toSet();
    double totalScore = 0.0;
    for (final qToken in queryTokens) {
      double bestMatch = 0.0;
      for (final tToken in textTokens) {
        if (tToken == qToken) { bestMatch = 1.0; break; }
        if (tToken.contains(qToken) || qToken.contains(tToken)) bestMatch = max(bestMatch, 0.8);
        final distance = _levenshteinDistanceStatic(tToken, qToken);
        if (distance <= 2) bestMatch = max(bestMatch, 0.7 - (distance / 10.0));
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

  static int _levenshteinDistanceStatic(String a, String b) {
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

  Future<List<Product>> _searchRemote(String normalizedQuery, {int limit = _defaultLimit}) async {
    try {
      return await _api.searchProducts(query: normalizedQuery, limit: limit);
    } catch (e) {
      debugPrint('Remote search failed: $e');
      return [];
    }
  }

  Future<void> _searchRemoteAndUpdateLocal(String normalizedQuery, {int limit = _defaultLimit}) async {
    try {
      final remoteResults = await _api.searchProducts(query: normalizedQuery, limit: limit);
      if (remoteResults.isNotEmpty) {
        await _updateLocalProducts(remoteResults);
        _updateCache(normalizedQuery, remoteResults);
      }
    } catch (e) {
      debugPrint('Background update failed: $e');
    }
  }

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

  List<Product>? _getFromCache(String query) {
    final cached = _cache[query];
    if (cached != null && !cached.isExpired) return cached.results;
    _cache.remove(query);
    return null;
  }

  void _updateCache(String query, List<Product> results) {
    _cache[query] = _CachedResult(results);
  }

  static String _normalizeText(String input) {
    if (input.isEmpty) return '';
    String normalized = input;
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabicNumbers.length; i++) {
      normalized = normalized.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    normalized = normalized.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.toLowerCase();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _cache.clear();
  }
}

class _CachedResult {
  final List<Product> results;
  final DateTime timestamp;
  static const int _cacheTtlSeconds = 300;
  _CachedResult(this.results) : timestamp = DateTime.now();
  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > _cacheTtlSeconds;
}

class _SearchParams {
  final List<Product> products;
  final String query;
  final int limit;
  _SearchParams(this.products, this.query, this.limit);
}