import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import 'api_service.dart';

/// نتيجة عملية المزامنة
class SyncResult {
  final bool success;
  final int inserted;
  final int updated;
  final String? error;

  const SyncResult({
    required this.success,
    this.inserted = 0,
    this.updated = 0,
    this.error,
  });
}

/// خدمة مزامنة احترافية مع دعم API الداخلي
class SyncService {
  final ApiService _api;
  final Box<Product> _productBox;
  final Connectivity _connectivity = Connectivity();

  static const int _batchSize = 50;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 3);

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _retryTimer;
  StreamSubscription? _connectivitySubscription;

  SyncService(this._api, this._productBox) {
    _loadLastSyncTime();
    _monitorConnectivity();
  }

  // ---------- إدارة وقت المزامنة ----------
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('last_sync_time');
    if (ts != null) _lastSyncTime = DateTime.tryParse(ts);
  }

  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', time.toIso8601String());
    _lastSyncTime = time;
  }

  // ---------- مراقبة الاتصال ----------
  void _monitorConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && _lastSyncTime != null) {
        final diff = DateTime.now().difference(_lastSyncTime!);
        if (diff > _minSyncInterval) {
          syncDelta().then((_) => debugPrint('Auto-sync completed'));
        }
      }
    });
  }

  Future<bool> _hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ---------- المزامنة التدريجية (Delta) ----------
  Future<SyncResult> syncDelta({bool force = false}) async {
    if (_isSyncing) {
      debugPrint('Sync already in progress');
      return const SyncResult(success: false, error: 'مزامنة قيد التنفيذ');
    }
    if (!await _hasInternet()) {
      return const SyncResult(success: false, error: 'لا يوجد إنترنت');
    }
    if (!force && _lastSyncTime != null) {
      final diff = DateTime.now().difference(_lastSyncTime!);
      if (diff < _minSyncInterval) {
        debugPrint('Skipping sync – last sync was ${diff.inMinutes} min ago');
        return const SyncResult(success: true);
      }
    }

    _isSyncing = true;
    int inserted = 0, updated = 0;
    try {
      final after = _lastSyncTime?.toIso8601String() ?? DateTime(1970).toIso8601String();
      final serverProducts = await _api.fetchProducts(
        page: 1,
        pageSize: _batchSize,
      );

      for (final sp in serverProducts) {
        final local = _productBox.get(sp.sku);
        if (local == null) {
          await _productBox.put(sp.sku, sp);
          inserted++;
        } else if (local.updatedAt.isBefore(sp.updatedAt)) {
          await _productBox.put(sp.sku, sp);
          updated++;
        }
      }
      await _saveLastSyncTime(DateTime.now());
      return SyncResult(success: true, inserted: inserted, updated: updated);
    } catch (e) {
      debugPrint('Delta sync error: $e');
      return SyncResult(success: false, error: e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  // ---------- المزامنة الكاملة (Full) مع Pagination ----------
  Future<SyncResult> fullSync() async {
    if (_isSyncing) return const SyncResult(success: false, error: 'مزامنة قيد التنفيذ');
    if (!await _hasInternet()) return const SyncResult(success: false, error: 'لا يوجد إنترنت');

    _isSyncing = true;
    int inserted = 0, updated = 0, page = 1;
    try {
      while (true) {
        final products = await _api.fetchProducts(page: page, pageSize: _batchSize);
        if (products.isEmpty) break;
        for (final sp in products) {
          final local = _productBox.get(sp.sku);
          if (local == null) {
            await _productBox.put(sp.sku, sp);
            inserted++;
          } else if (local.updatedAt.isBefore(sp.updatedAt)) {
            await _productBox.put(sp.sku, sp);
            updated++;
          }
        }
        page++;
        debugPrint('Full sync page $page done');
      }
      await _saveLastSyncTime(DateTime.now());
      return SyncResult(success: true, inserted: inserted, updated: updated);
    } catch (e) {
      debugPrint('Full sync error: $e');
      return SyncResult(success: false, error: e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  // ---------- رفع المنتجات المعلقة ----------
  Future<SyncResult> uploadPendingProducts() async {
    if (!await _hasInternet()) return const SyncResult(success: false, error: 'لا يوجد إنترنت');
    final pending = _productBox.values.where((p) => p.syncStatus == 'pending').toList();
    if (pending.isEmpty) return const SyncResult(success: true);
    int uploaded = 0, failed = 0;
    for (int i = 0; i < pending.length; i += _batchSize) {
      final batch = pending.skip(i).take(_batchSize).toList();
      try {
        final list = batch.map((p) => p.toJson()).toList();
        await _api.importProductsBatch(list);
        for (final p in batch) {
          final existing = _productBox.get(p.sku);
          if (existing != null) {
            final updated = Product(
              sku: existing.sku,
              name: existing.name,
              category: existing.category,
              unit: existing.unit,
              unitPrice: existing.unitPrice,
              stockQuantity: existing.stockQuantity,
              imageUrls: existing.imageUrls,
              lastUpdated: DateTime.now(),
              syncStatus: 'synced',
            );
            await _productBox.put(existing.sku, updated);
            uploaded++;
          }
        }
      } catch (e) {
        debugPrint('Failed to upload batch: $e');
        failed += batch.length;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return SyncResult(success: true, inserted: uploaded, updated: 0);
  }

  // ---------- مزامنة شاملة مع إعادة المحاولة ----------
  Future<SyncResult> syncAll() async {
    if (!await _hasInternet()) return const SyncResult(success: false, error: 'لا يوجد إنترنت');
    await uploadPendingProducts();
    return await syncDelta(force: true);
  }

  // ---------- إعادة المحاولة الذكية ----------
  Future<SyncResult> syncWithRetry() async {
    int attempts = 0;
    Duration delay = _initialRetryDelay;
    while (attempts < _maxRetries) {
      final result = await syncAll();
      if (result.success) return result;
      attempts++;
      debugPrint('Retry $attempts in ${delay.inSeconds}s');
      await Future.delayed(delay);
      delay *= 2;
    }
    return const SyncResult(success: false, error: 'فشلت كل المحاولات');
  }

  // ---------- حالة المزامنة ----------
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }
}
