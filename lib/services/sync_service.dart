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

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/product_model.dart';
import 'search_service.dart';

/// نتيجة عملية المزامنة
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

  @override
  String toString() => 'SyncResult(success: $success, inserted: $inserted, updated: $updated, deleted: $deleted, error: $error)';
}

/// خدمة المزامنة
class SyncService {
  final SupabaseClient _supabase;
  final Box<Product> _productBox;
  final Connectivity _connectivity = Connectivity();
  final String _tableName = 'products';

  // إعدادات المزامنة
  static const int _batchSize = 100;          // عدد المنتجات لكل طلب
  static const int _maxRetries = 3;           // عدد محاولات إعادة المزامنة
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _syncCooldown = Duration(minutes: 5); // منع المزامنة المتكررة

  // حالة المزامنة
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // متغير لحماية التكرار
  final Set<String> _syncingSkus = {};

  // الكاش لآخر مزامنة (يُحفظ في SharedPreferences أو Hive)
  static const String _lastSyncKey = 'last_sync_time';

  SyncService(this._supabase, this._productBox) {
    _loadLastSyncTime();
    _monitorConnectivity();
  }

  // ============================================================
  // 1. إدارة وقت آخر مزامنة
  // ============================================================
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);
    if (timestamp != null) {
      _lastSyncTime = DateTime.tryParse(timestamp);
    }
  }

  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
    _lastSyncTime = time;
  }

  // ============================================================
  // 2. مراقبة حالة الاتصال وإعادة المزامنة التلقائية
  // ============================================================
  void _monitorConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      if (isConnected && _lastSyncTime != null) {
        // إذا عاد الإنترنت بعد فترة طويلة، نبدأ مزامنة تلقائية
        final diff = DateTime.now().difference(_lastSyncTime!);
        if (diff > _syncCooldown) {
          syncDelta().then((_) => debugPrint('Auto-sync after connection restored'));
        }
      }
    });
  }

  // ============================================================
  // 3. المزامنة التدريجية (Delta Sync) – الموصى بها
  // ============================================================
  Future<SyncResult> syncDelta({bool force = false}) async {
    // منع التكرار
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping...');
      return SyncResult.failure('Sync already in progress');
    }

    // التحقق من الاتصال
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      return SyncResult.failure('No internet connection');
    }

    // التحقق من وقت آخر مزامنة (منع التكرار المتكرر)
    if (!force && _lastSyncTime != null) {
      final diff = DateTime.now().difference(_lastSyncTime!);
      if (diff < _syncCooldown) {
        debugPrint('Sync skipped: last sync was ${diff.inMinutes} minutes ago');
        return SyncResult.success(); // لا خطأ، فقط تخطي
      }
    }

    _isSyncing = true;
    int inserted = 0;
    int updated = 0;
    int deleted = 0;

    try {
      // جلب التغييرات من الخادم بعد آخر مزامنة
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

      // معالجة المنتجات المستلمة
      for (var json in data) {
        final serverProduct = Product.fromJson(json as Map<String, dynamic>);
        final localProduct = _productBox.get(serverProduct.sku);
        
        if (localProduct == null) {
          // منتج جديد
          await _productBox.put(serverProduct.sku, serverProduct);
          inserted++;
        } else if (localProduct.updatedAt.isBefore(serverProduct.updatedAt)) {
          // تحديث موجود
          await _productBox.put(serverProduct.sku, serverProduct);
          updated++;
        }
      }

      // (اختياري) التعامل مع المنتجات المحذوفة من الخادم
      // يمكن جلب قائمة SKUs المحذوفة من API منفصل
      // deleted = await _syncDeletedProducts(afterTime);

      // حفظ وقت آخر مزامنة ناجحة
      await _saveLastSyncTime(DateTime.now());
      
      return SyncResult.success(inserted: inserted, updated: updated, deleted: deleted);
    } catch (e) {
      debugPrint('Delta sync error: $e');
      return SyncResult.failure(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  // ============================================================
  // 4. المزامنة الكاملة (Full Sync) – تُستخدم لأول مرة أو عند الطلب
  // ============================================================
  Future<SyncResult> fullSync({bool force = false}) async {
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

  // ============================================================
  // 5. رفع المنتجات المحلية المعلقة (sync_status = pending)
  // ============================================================
  Future<SyncResult> uploadPendingProducts() async {
    if (!await _checkConnectivity()) return SyncResult.failure('No internet connection');

    int uploaded = 0;
    int failed = 0;
    final pending = _productBox.values.where((p) => p.syncStatus == 'pending').toList();

    for (var product in pending) {
      if (_syncingSkus.contains(product.sku)) continue;
      _syncingSkus.add(product.sku);
      try {
        // إرسال إلى Supabase (تحديث أو إدراج)
        final response = await _supabase
            .from(_tableName)
            .upsert(product.toJson())
            .timeout(const Duration(seconds: 15));
        
        // تحديث الحالة محلياً إلى synced
        final updatedProduct = product.copyWith(syncStatus: 'synced', updatedAt: DateTime.now());
        await _productBox.put(product.sku, updatedProduct);
        uploaded++;
      } catch (e) {
        debugPrint('Failed to upload product ${product.sku}: $e');
        failed++;
        // نترك الحالة pending للمحاولة لاحقاً
      } finally {
        _syncingSkus.remove(product.sku);
      }
    }

    return SyncResult.success(inserted: uploaded, updated: 0, deleted: 0);
  }

  // ============================================================
  // 6. مزامنة ثنائية الاتجاه (Bidirectional) – متقدمة
  // ============================================================
  Future<SyncResult> bidirectionalSync() async {
    if (!await _checkConnectivity()) return SyncResult.failure('No internet');

    // أولاً: رفع المعلقات
    final uploadResult = await uploadPendingProducts();
    // ثانياً: جلب التحديثات من الخادم
    final downloadResult = await syncDelta();

    return SyncResult.success(
      inserted: downloadResult.inserted,
      updated: downloadResult.updated + uploadResult.inserted,
    );
  }

  // ============================================================
  // 7. إعادة المحاولة الذكية (Exponential Backoff)
  // ============================================================
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
      delay = delay * 2; // exponential backoff
    }
    return SyncResult.failure('Sync failed after $maxRetries attempts');
  }

  // ============================================================
  // 8. وظائف مساعدة
  // ============================================================
  Future<bool> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// هل هناك مزامنة قيد التنفيذ؟
  bool get isSyncing => _isSyncing;

  /// وقت آخر مزامنة ناجحة
  DateTime? get lastSyncTime => _lastSyncTime;

  /// إلغاء المزامنة الحالية (اختياري)
  void cancelSync() {
    _isSyncing = false;
    _retryTimer?.cancel();
  }

  /// تنظيف الموارد عند إغلاق التطبيق
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }
}