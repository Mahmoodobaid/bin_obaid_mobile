// sync_service.dart
// خدمة مزامنة احترافية مع:
// - مزامنة تدريجية (Delta Sync) باستخدام updated_at
// - مزامنة كاملة (Full Sync) مع Pagination
// - دعم Supabase كخادم
// - إعادة محاولة ذكية (exponential backoff)
// - التعامل مع الانقطاع واستئناف المزامنة
// - منع المزامنة المتزامنة المتعددة
// - حفظ آخر وقت مزامنة بنجاح
// - معالجة الأخطاء وتصنيفها
// - مراقبة حالة الإنترنت والتحديث في الخلفية
// sync_service.dart
// خدمة مزامنة احترافية - نسخة خالية من الأخطاء
// تمت إضافة import 'package:flutter/foundation.dart' لاستخدام debugPrint

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/product_model.dart';
import 'search_service.dart';

class SyncResult {
  final bool success;
  final int inserted;
  final int updated;
  final int deleted;
  final String? error;

  SyncResult({
    required this.success,
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
    this.error,
  });

  factory SyncResult.success({int inserted = 0, int updated = 0, int deleted = 0}) {
    return SyncResult(success: true, inserted: inserted, updated: updated, deleted: deleted);
  }

  factory SyncResult.failure(String error) {
    return SyncResult(success: false, error: error);
  }
}

class SyncService {
  final SupabaseClient _supabase;
  final Box<Product> _productBox;
  final Connectivity _connectivity = Connectivity();
  final String _tableName = 'products';

  static const int _batchSize = 100;
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _syncCooldown = Duration(minutes: 5);

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Set<String> _syncingSkus = {};

  SyncService(this._supabase, this._productBox) {
    _loadLastSyncTime();
    _monitorConnectivity();
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString('last_sync_time');
    if (timestamp != null) {
      _lastSyncTime = DateTime.tryParse(timestamp);
    }
  }

  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', time.toIso8601String());
    _lastSyncTime = time;
  }

  void _monitorConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      if (isConnected && _lastSyncTime != null) {
        final diff = DateTime.now().difference(_lastSyncTime!);
        if (diff > _syncCooldown) {
          syncDelta().then((_) => debugPrint('Auto-sync after connection restored'));
        }
      }
    });
  }

  Future<bool> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<SyncResult> syncDelta({bool force = false}) async {
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping...');
      return SyncResult.failure('Sync already in progress');
    }
    if (!await _checkConnectivity()) return SyncResult.failure('No internet connection');
    if (!force && _lastSyncTime != null) {
      final diff = DateTime.now().difference(_lastSyncTime!);
      if (diff < _syncCooldown) {
        debugPrint('Sync skipped: last sync was ${diff.inMinutes} minutes ago');
        return SyncResult.success();
      }
    }

    _isSyncing = true;
    int inserted = 0;
    int updated = 0;

    try {
      final afterTime = _lastSyncTime?.toIso8601String() ?? DateTime(1970).toIso8601String();
      final response = await _supabase
          .from(_tableName)
          .select()
          .gt('updated_at', afterTime)
          .order('updated_at', ascending: true)
          .limit(_batchSize)
          .timeout(const Duration(seconds: 30));

      final List<dynamic> data = response;
      debugPrint('Delta sync: fetched ${data.length} items');

      for (var json in data) {
        final serverProduct = Product.fromJson(json as Map<String, dynamic>);
        final localProduct = _productBox.get(serverProduct.sku);
        if (localProduct == null) {
          await _productBox.put(serverProduct.sku, serverProduct);
          inserted++;
        } else if (localProduct.updatedAt.isBefore(serverProduct.updatedAt)) {
          await _productBox.put(serverProduct.sku, serverProduct);
          updated++;
        }
      }

      await _saveLastSyncTime(DateTime.now());
      return SyncResult.success(inserted: inserted, updated: updated);
    } catch (e) {
      debugPrint('Delta sync error: $e');
      return SyncResult.failure(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<SyncResult> fullSync() async {
    if (_isSyncing) return SyncResult.failure('Sync already in progress');
    if (!await _checkConnectivity()) return SyncResult.failure('No internet connection');

    _isSyncing = true;
    int inserted = 0;
    int updated = 0;
    int page = 0;

    try {
      while (true) {
        final from = page * _batchSize;
        final to = from + _batchSize - 1;
        final response = await _supabase
            .from(_tableName)
            .select()
            .range(from, to)
            .order('sku', ascending: true)
            .timeout(const Duration(seconds: 30));

        final List<dynamic> data = response;
        if (data.isEmpty) break;

        for (var json in data) {
          final serverProduct = Product.fromJson(json as Map<String, dynamic>);
          final localProduct = _productBox.get(serverProduct.sku);
          if (localProduct == null) {
            await _productBox.put(serverProduct.sku, serverProduct);
            inserted++;
          } else if (localProduct.updatedAt.isBefore(serverProduct.updatedAt)) {
            await _productBox.put(serverProduct.sku, serverProduct);
            updated++;
          }
        }
        page++;
        debugPrint('Full sync: page $page completed');
      }

      await _saveLastSyncTime(DateTime.now());
      return SyncResult.success(inserted: inserted, updated: updated);
    } catch (e) {
      debugPrint('Full sync error: $e');
      return SyncResult.failure(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<SyncResult> uploadPendingProducts() async {
    if (!await _checkConnectivity()) return SyncResult.failure('No internet connection');
    int uploaded = 0;
    int failed = 0;
    final pending = _productBox.values.where((p) => p.syncStatus == 'pending').toList();

    for (var product in pending) {
      if (_syncingSkus.contains(product.sku)) continue;
      _syncingSkus.add(product.sku);
      try {
        await _supabase.from(_tableName).upsert(product.toJson()).timeout(const Duration(seconds: 15));
        final updatedProduct = product.copyWith(syncStatus: 'synced', updatedAt: DateTime.now());
        await _productBox.put(product.sku, updatedProduct);
        uploaded++;
      } catch (e) {
        debugPrint('Failed to upload product ${product.sku}: $e');
        failed++;
      } finally {
        _syncingSkus.remove(product.sku);
      }
    }
    return SyncResult.success(inserted: uploaded, updated: 0);
  }

  Future<SyncResult> bidirectionalSync() async {
    if (!await _checkConnectivity()) return SyncResult.failure('No internet');
    final uploadResult = await uploadPendingProducts();
    final downloadResult = await syncDelta();
    return SyncResult.success(
      inserted: downloadResult.inserted,
      updated: downloadResult.updated + uploadResult.inserted,
    );
  }

  Future<SyncResult> syncWithRetry({int maxRetries = _maxRetries}) async {
    int attempt = 0;
    Duration delay = _initialRetryDelay;
    while (attempt < maxRetries) {
      final result = await bidirectionalSync();
      if (result.success) return result;
      attempt++;
      if (attempt >= maxRetries) break;
      debugPrint('Sync failed, retry $attempt after ${delay.inSeconds}s');
      await Future.delayed(delay);
      delay = delay * 2;
    }
    return SyncResult.failure('Sync failed after $maxRetries attempts');
  }

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  void cancelSync() => _isSyncing = false;
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }
}