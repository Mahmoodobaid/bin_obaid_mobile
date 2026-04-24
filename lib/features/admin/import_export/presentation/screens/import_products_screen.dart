import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/config/config.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/permission_service.dart';

// قائمة الحقول الأساسية مع وصف لكل حقل
const List<Map<String, String>> defaultDbFieldsWithDesc = [
  {'name': 'sku', 'desc': 'رمز المنتج الفريد (مطلوب)'},
  {'name': 'barcode', 'desc': 'الباركود (بديل عن SKU)'},
  {'name': 'name', 'desc': 'اسم المنتج'},
  {'name': 'description', 'desc': 'وصف المنتج'},
  {'name': 'category', 'desc': 'التصنيف'},
  {'name': 'unit', 'desc': 'وحدة القياس (قطعة، كجم، لتر...)'},
  {'name': 'unit_price', 'desc': 'سعر الوحدة'},
  {'name': 'wholesale_price', 'desc': 'سعر الجملة'},
  {'name': 'stock_quantity', 'desc': 'الكمية المتاحة'},
  {'name': 'min_stock', 'desc': 'الحد الأدنى للمخزون'},
  {'name': 'location', 'desc': 'موقع التخزين'},
  {'name': 'notes', 'desc': 'ملاحظات إضافية'},
];

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  ConsumerState<ImportProductsScreen> createState() =>
      _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen>
    with SingleTickerProviderStateMixin {
  // ---------- متغيرات الملف ----------
  File? _selectedFile;
  String? _fileName;
  bool _isLoadingFile = false;
  String _fileType = ''; // 'excel' or 'csv'

  // ---------- بيانات Excel/CSV ----------
  List<String> _excelColumns = [];
  List<String> _sheetNames = [];
  String _selectedSheet = '';
  int _headerRowIndex = 0;
  List<List<dynamic>> _rawRows = []; // كل الصفوف بعد صف العناوين

  // ---------- حقول قاعدة البيانات (قابلة للتخصيص) ----------
  List<Map<String, String>> _dbFieldsWithDesc =
      List.from(defaultDbFieldsWithDesc);
  List<String> get _dbFields => _dbFieldsWithDesc.map((e) => e['name']!).toList();
  Map<String, String?> _columnMapping = {}; // حقل قاعدة البيانات -> اسم العمود في الملف
  Map<String, String> _columnDescriptions = {}; // وصف لكل حقل

  // ---------- خيارات الاستيراد ----------
  String _quantityMergeOption = 'add'; // add, replace, ignore
  bool _updateExistingOnly = false;
  bool _autoMapColumns = true; // محاولة المطابقة التلقائية
  bool _deleteLocalBeforeImport = false; // حذف البيانات المحلية قبل الاستيراد

  // ---------- حالة الواجهة ----------
  bool _isImporting = false;
  bool _isPreviewLoading = false;
  List<Map<String, dynamic>> _previewRows = [];
  double _progress = 0;
  String _statusMessage = 'جاهز للاستيراد';
  bool _hasInternet = false;
  CancelToken? _cancelToken; // لإلغاء الاستيراد

  // ---------- إحصائيات الاستيراد ----------
  int _newItemsCount = 0;
  int _updatedItemsCount = 0;
  int _skippedItemsCount = 0;
  int _errorItemsCount = 0;
  final List<String> _errorLogs = [];

  // ---------- Hive ----------
  late Box _productBox;
  late Box _importLogsBox;

  // ---------- Animation ----------
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkInternet();
    await _loadSavedSettings();
    _productBox = await Hive.openBox('products');
    _importLogsBox = await Hive.openBox('import_logs');
    _resetMapping();
    _loadColumnDescriptions();
    if (mounted) setState(() {});
  }

  void _loadColumnDescriptions() {
    _columnDescriptions = {
      for (var field in _dbFieldsWithDesc) field['name']!: field['desc']!,
    };
  }

  Future<void> _checkInternet() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _hasInternet = connectivity != ConnectivityResult.none);
    }
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _headerRowIndex = prefs.getInt('excel_header_row') ?? 0;
    _quantityMergeOption = prefs.getString('excel_quantity_option') ?? 'add';
    _updateExistingOnly = prefs.getBool('excel_update_only') ?? false;
    _autoMapColumns = prefs.getBool('excel_auto_map') ?? true;
    _deleteLocalBeforeImport = prefs.getBool('excel_delete_local') ?? false;

    final savedFields = prefs.getStringList('excel_db_fields');
    if (savedFields != null && savedFields.isNotEmpty) {
      _dbFieldsWithDesc = savedFields.map((f) => {'name': f, 'desc': ''}).toList();
      _loadColumnDescriptions();
    }

    final savedMapping = prefs.getString('excel_column_mapping');
    if (savedMapping != null) {
      try {
        final decoded = jsonDecode(savedMapping) as Map<String, dynamic>;
        _columnMapping = decoded.map((k, v) => MapEntry(k, v?.toString()));
      } catch (_) {}
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('excel_header_row', _headerRowIndex);
    await prefs.setString('excel_quantity_option', _quantityMergeOption);
    await prefs.setBool('excel_update_only', _updateExistingOnly);
    await prefs.setBool('excel_auto_map', _autoMapColumns);
    await prefs.setBool('excel_delete_local', _deleteLocalBeforeImport);
    await prefs.setStringList('excel_db_fields', _dbFields);
    await prefs.setString('excel_column_mapping', jsonEncode(_columnMapping));
  }

  void _resetMapping() {
    _columnMapping = {for (var f in _dbFields) f: null};
    if (_autoMapColumns && _excelColumns.isNotEmpty) {
      _autoMapColumnsFromExcel();
    }
  }

  void _autoMapColumnsFromExcel() {
    final newMapping = <String, String?>{};
    for (var field in _dbFields) {
      final lowerField = field.toLowerCase();
      String? matchedColumn;
      for (var col in _excelColumns) {
        final lowerCol = col.toLowerCase();
        if (lowerCol.contains(lowerField) ||
            lowerField.contains(lowerCol) ||
            _similarity(lowerField, lowerCol) > 0.6) {
          matchedColumn = col;
          break;
        }
      }
      newMapping[field] = matchedColumn;
    }
    setState(() {
      _columnMapping = newMapping;
    });
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final setA = a.split('').toSet();
    final setB = b.split('').toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return intersection / union;
  }

  Future<void> _pickFile() async {
    try {
      setState(() => _isLoadingFile = true);
      await PermissionService.requestStorage(context);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );
      if (result == null || result.files.single.path == null) {
        if (mounted) setState(() => _isLoadingFile = false);
        return;
      }
      _selectedFile = File(result.files.single.path!);
      _fileName = result.files.single.name;
      _fileType = _fileName!.toLowerCase().endsWith('.csv') ? 'csv' : 'excel';
      await _loadFileData();
      if (mounted) setState(() => _isLoadingFile = false);
    } catch (e) {
      if (mounted) setState(() => _isLoadingFile = false);
      _showError('حدث خطأ أثناء اختيار الملف: $e');
    }
  }

  Future<void> _loadFileData() async {
    if (_selectedFile == null) return;
    try {
      if (_fileType == 'csv') {
        await _loadCsvData();
      } else {
        await _loadExcelData();
      }
      if (_autoMapColumns && _excelColumns.isNotEmpty) {
        _autoMapColumnsFromExcel();
      }
      if (mounted) setState(() {});
    } catch (e) {
      _showError('تعذر تحليل الملف: $e');
    }
  }

  Future<void> _loadExcelData() async {
    final bytes = await _selectedFile!.readAsBytes();
    final excel = excel_lib.Excel.decodeBytes(bytes);
    _sheetNames = excel.tables.keys.toList();
    if (_sheetNames.isEmpty) throw Exception('لا يحتوي الملف على أوراق');
    _selectedSheet = _sheetNames.first;
    final sheet = excel.tables[_selectedSheet]!;
    if (sheet.rows.isEmpty) throw Exception('الورقة فارغة');
    if (_headerRowIndex >= sheet.rows.length) _headerRowIndex = 0;
    final headerRow = sheet.rows[_headerRowIndex];
    _excelColumns = headerRow
        .map((cell) => _cleanText(cell?.value))
        .where((e) => e.isNotEmpty)
        .toList();
    _rawRows = sheet.rows.skip(_headerRowIndex + 1).toList();
  }

  Future<void> _loadCsvData() async {
    final fileContent = await _selectedFile!.readAsString();
    if (rows.isEmpty) throw Exception('ملف CSV فارغ');
    if (_headerRowIndex >= rows.length) _headerRowIndex = 0;
    _excelColumns = rows[_headerRowIndex]
        .map((cell) => _cleanText(cell))
        .where((e) => e.isNotEmpty)
        .toList();
    _rawRows = rows.skip(_headerRowIndex + 1).toList();
    _sheetNames = ['CSV'];
    _selectedSheet = 'CSV';
  }

  String _cleanText(dynamic value) {
    return value?.toString().replaceAll('\n', ' ').replaceAll('\r', ' ').trim() ?? '';
  }

  Future<void> _loadPreview() async {
    if (_selectedFile == null) return;
    setState(() => _isPreviewLoading = true);
    try {
      final previewRows = <Map<String, dynamic>>[];
      for (int i = 0; i < (_rawRows.length > 5 ? 5 : _rawRows.length); i++) {
        final row = _rawRows[i];
        final item = <String, dynamic>{};
        for (final entry in _columnMapping.entries) {
          if (entry.value == null) continue;
          final idx = _excelColumns.indexOf(entry.value!);
          if (idx != -1 && idx < row.length) {
            item[entry.key] = _convertValue(entry.key, row[idx]);
          }
        }
        previewRows.add(item);
      }
      setState(() => _previewRows = previewRows);
    } catch (e) {
      _showError('فشل تحميل المعاينة: $e');
    } finally {
      if (mounted) setState(() => _isPreviewLoading = false);
    }
  }

  dynamic _convertValue(String field, dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (field.contains('price') || field.contains('stock') || field.contains('quantity')) {
      return _toDouble(text);
    }
    return _cleanText(value);
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    final cleaned = v.toString().replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _startImport() async {
    if (_selectedFile == null) {
      _showError('يرجى اختيار ملف أولاً');
      return;
    }
    if (_columnMapping['sku'] == null && _columnMapping['barcode'] == null) {
      _showError('يجب ربط حقل SKU أو Barcode على الأقل');
      return;
    }
    await _saveSettings();

    // تأكيد الحذف إذا كان الخيار مفعلاً
    if (_deleteLocalBeforeImport) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تحذير!'),
          content: const Text('سيتم حذف جميع المنتجات المحلية قبل الاستيراد. هل أنت متأكد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف واستيراد')),
          ],
        ),
      );
      if (confirm != true) return;
      await _productBox.clear();
    }

    if (!mounted) return;
    setState(() {
      _isImporting = true;
      _progress = 0;
      _newItemsCount = 0;
      _updatedItemsCount = 0;
      _skippedItemsCount = 0;
      _errorItemsCount = 0;
      _errorLogs.clear();
      _statusMessage = 'بدء الاستيراد...';
      _cancelToken = CancelToken();
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final List<Map<String, dynamic>> pendingServerSync = [];
      final int totalRows = _rawRows.length;
      int processed = 0;

      for (int rowIndex = 0; rowIndex < totalRows; rowIndex++) {
        if (_cancelToken!.isCancelled) {
          _statusMessage = 'تم إلغاء الاستيراد';
          break;
        }
        try {
          final row = _rawRows[rowIndex];
          final product = <String, dynamic>{};
          for (final entry in _columnMapping.entries) {
            if (entry.value == null) continue;
            final idx = _excelColumns.indexOf(entry.value!);
            if (idx == -1 || idx >= row.length) continue;
            product[entry.key] = _convertValue(entry.key, row[idx]);
          }
          String? sku = product['sku']?.toString().trim();
          if (sku == null || sku.isEmpty) {
            sku = product['barcode']?.toString().trim();
          }
          if (sku == null || sku.isEmpty) {
            _skippedItemsCount++;
            processed++;
            continue;
          }
          final existing = _productBox.get(sku);

          if (existing != null) {
            final updated = Map<String, dynamic>.from(existing);
            updated.addAll(product);
            if (_quantityMergeOption == 'add') {
              final oldQty = _toDouble(existing['stock_quantity']);
              final newQty = _toDouble(product['stock_quantity']);
              updated['stock_quantity'] = oldQty + newQty;
            } else if (_quantityMergeOption == 'ignore') {
              updated['stock_quantity'] = existing['stock_quantity'];
            }
            updated['updated_at'] = DateTime.now().toIso8601String();
            updated['sync_status'] = 'pending';
            await _productBox.put(sku, updated);
            pendingServerSync.add(updated);
            _updatedItemsCount++;
          } else {
            if (_updateExistingOnly) {
              _skippedItemsCount++;
            } else {
              final newProduct = {
                ...product,
                'sku': sku,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
                'sync_status': 'pending',
              };
              await _productBox.put(sku, newProduct);
              pendingServerSync.add(newProduct);
              _newItemsCount++;
            }
          }
        } catch (e) {
          _errorItemsCount++;
          _errorLogs.add('صف ${rowIndex + _headerRowIndex + 2}: $e');
        }
        processed++;
        setState(() {
          _progress = processed / totalRows;
          _statusMessage = 'تمت معالجة $processed من $totalRows';
        });
        await Future.delayed(const Duration(milliseconds: 2));
      }

      if (_hasInternet && pendingServerSync.isNotEmpty && !_cancelToken!.isCancelled) {
        setState(() => _statusMessage = 'مزامنة مع الخادم...');
        const batchSize = 20;
        for (int i = 0; i < pendingServerSync.length; i += batchSize) {
          if (_cancelToken!.isCancelled) break;
          final batch = pendingServerSync.skip(i).take(batchSize).toList();
          try {
            await apiService.importProductsBatch(batch);
            for (final item in batch) {
              final s = item['sku'];
              final existing = _productBox.get(s);
              if (existing != null) {
                existing['sync_status'] = 'synced';
                existing['last_sync_at'] = DateTime.now().toIso8601String();
                await _productBox.put(s, existing);
              }
            }
          } catch (e) {
            _errorLogs.add('فشل مزامنة دفعة: $e');
          }
        }
      }

      await _importLogsBox.add({
        'file_name': _fileName,
        'date': DateTime.now().toIso8601String(),
        'new_items': _newItemsCount,
        'updated_items': _updatedItemsCount,
        'errors': _errorItemsCount,
        'total_rows': totalRows,
      });

      if (mounted) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'اكتمل الاستيراد';
        });
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        _showError('فشل الاستيراد: $e');
      }
    }
  }

  void _cancelImport() {
    if (_cancelToken != null) {
      _cancelToken!.cancel();
      setState(() {
        _isImporting = false;
        _statusMessage = 'تم إلغاء الاستيراد';
      });
      _showError('تم إلغاء عملية الاستيراد');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red.shade700, content: Text(msg)),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            const Text('تقرير الاستيراد'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportItem('جديد', _newItemsCount, Colors.green),
              _buildReportItem('محدث', _updatedItemsCount, Colors.blue),
              _buildReportItem('متجاهل', _skippedItemsCount, Colors.orange),
              _buildReportItem('أخطاء', _errorItemsCount, Colors.red),
              if (_errorLogs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('سجل الأخطاء:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  height: 140,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    itemCount: _errorLogs.length,
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(_errorLogs[i], style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _errorLogs.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الأخطاء')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('نسخ'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _exportErrorLog,
                      icon: const Icon(Icons.save_alt, size: 16),
                      label: const Text('تصدير'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetAfterImport();
            },
            child: const Text('استيراد جديد'),
          ),
        ],
      ),
    );
  }

  void _resetAfterImport() {
    setState(() {
      _selectedFile = null;
      _fileName = null;
      _excelColumns = [];
      _rawRows = [];
      _previewRows = [];
      _progress = 0;
      _newItemsCount = 0;
      _updatedItemsCount = 0;
      _skippedItemsCount = 0;
      _errorItemsCount = 0;
      _errorLogs.clear();
      _statusMessage = 'جاهز للاستيراد';
      _resetMapping();
    });
  }

  Widget _buildReportItem(String title, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _exportErrorLog() async {
    final logText = _errorLogs.join('\n');
    await Clipboard.setData(ClipboardData(text: logText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الأخطاء إلى الحافظة')),
      );
    }
  }

  Future<void> _resyncPending() async {
    if (!_hasInternet) {
      _showError('لا يوجد اتصال بالإنترنت');
      return;
    }
    final pending = _productBox.values.where((e) => e['sync_status'] == 'pending').toList();
    if (pending.isEmpty) {
      _showError('لا توجد عناصر معلقة');
      return;
    }
    final api = ref.read(apiServiceProvider);
    int synced = 0;
    for (int i = 0; i < pending.length; i += 20) {
      final batch = pending.skip(i).take(20).toList();
      try {
        await api.importProductsBatch(batch.map((e) => Map<String, dynamic>.from(e)).toList());
        for (final item in batch) {
          item['sync_status'] = 'synced';
          await _productBox.put(item['sku'], item);
          synced++;
        }
      } catch (e) {
        _showError('فشل مزامنة بعض العناصر: $e');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت مزامنة $synced عنصر')),
      );
    }
  }

  void _navigateToConnectionSettings() {
    context.push('/admin/connection-settings');
  }

  // ------------------------------- واجهة المستخدم المحسنة -------------------------------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          elevation: 0,
          title: const Text('استيراد المنتجات المتقدم'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_ethernet),
              onPressed: _navigateToConnectionSettings,
              tooltip: 'إعدادات الاتصال',
            ),
            IconButton(
              icon: const Icon(Icons.sync_problem),
              onPressed: _resyncPending,
              tooltip: 'إعادة مزامنة المعلق',
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildFileCard(),
              const SizedBox(height: 20),
              if (_excelColumns.isNotEmpty) ...[
                _buildSheetAndHeaderCard(),
                const SizedBox(height: 20),
                _buildMappingCard(),
                const SizedBox(height: 20),
                _buildOptionsCard(),
                const SizedBox(height: 20),
                _buildFieldsEditorCard(),
                const SizedBox(height: 20),
                _buildPreviewAndImportButtons(),
                if (_previewRows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildPreviewTable(),
                ],
              ],
              if (_isImporting) ...[
                const SizedBox(height: 20),
                _buildProgressCard(),
              ],
            ],
          ),
        ),
        floatingActionButton: _isImporting
            ? FloatingActionButton.extended(
                onPressed: _cancelImport,
                icon: const Icon(Icons.cancel),
                label: const Text('إلغاء'),
                backgroundColor: Colors.red,
              )
            : null,
      ),
    );
  }

  Widget _buildFileCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_upload, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Text('ملف البيانات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade50,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fileName ?? 'اسحب ملف Excel/CSV أو اضغط للاختيار',
                      style: TextStyle(color: _fileName == null ? Colors.grey : Colors.black87),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoadingFile ? null : _pickFile,
                    icon: _isLoadingFile
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.folder_open),
                    label: const Text('اختيار'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.cloud_queue, size: 16, color: _hasInternet ? Colors.green : Colors.red),
                const SizedBox(width: 6),
                Text(
                  _hasInternet ? 'متصل - سيتم المزامنة مع الخادم' : 'غير متصل - حفظ محلي فقط',
                  style: TextStyle(color: _hasInternet ? Colors.green : Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetAndHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_sheetNames.length > 1)
              DropdownButtonFormField<String>(
                value: _selectedSheet,
                decoration: const InputDecoration(
                  labelText: 'ورقة العمل',
                  prefixIcon: Icon(Icons.table_chart),
                  border: OutlineInputBorder(),
                ),
                items: _sheetNames.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) async {
                  setState(() => _selectedSheet = v!);
                  await _loadFileData();
                },
              ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: (_headerRowIndex + 1).toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم صف العناوين',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) async {
                _headerRowIndex = (int.tryParse(v) ?? 1) - 1;
                await _loadFileData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('ربط الأعمدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _resetMapping());
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة تعيين'),
                ),
                Switch(
                  value: _autoMapColumns,
                  onChanged: (v) {
                    setState(() {
                      _autoMapColumns = v;
                      if (_autoMapColumns) _autoMapColumnsFromExcel();
                    });
                  },
                ),
                const Text('تلقائي'),
              ],
            ),
            const SizedBox(height: 12),
            ..._dbFields.where((f) => f.isNotEmpty).map((field) {
              final usedColumns = _columnMapping.values.where((v) => v != null).toSet();
              final availableColumns = _excelColumns.where((c) => !usedColumns.contains(c) || _columnMapping[field] == c).toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(field, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        if (_columnDescriptions[field] != null && _columnDescriptions[field]!.isNotEmpty)
                          Tooltip(
                            message: _columnDescriptions[field],
                            child: Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _columnMapping[field],
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        hintText: 'اختر عمود...',
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-- غير محدد --')),
                        ...availableColumns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (v) => setState(() => _columnMapping[field] = v),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings),
                SizedBox(width: 8),
                Text('خيارات الاستيراد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('إضافة الكمية إلى المخزون الحالي'),
              value: 'add',
              groupValue: _quantityMergeOption,
              onChanged: (v) => setState(() => _quantityMergeOption = v!),
            ),
            RadioListTile<String>(
              title: const Text('استبدال الكمية بالكامل'),
              value: 'replace',
              groupValue: _quantityMergeOption,
              onChanged: (v) => setState(() => _quantityMergeOption = v!),
            ),
            RadioListTile<String>(
              title: const Text('تجاهل تحديث الكمية'),
              value: 'ignore',
              groupValue: _quantityMergeOption,
              onChanged: (v) => setState(() => _quantityMergeOption = v!),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('تحديث المنتجات الموجودة فقط (لا تضف منتجات جديدة)'),
              value: _updateExistingOnly,
              onChanged: (v) => setState(() => _updateExistingOnly = v),
            ),
            SwitchListTile(
              title: const Text('حذف جميع المنتجات المحلية قبل الاستيراد'),
              subtitle: const Text('تحذير: لا يمكن التراجع'),
              value: _deleteLocalBeforeImport,
              onChanged: (v) => setState(() => _deleteLocalBeforeImport = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsEditorCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        title: const Text('تخصيص حقول قاعدة البيانات', style: TextStyle(fontWeight: FontWeight.w500)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._dbFieldsWithDesc.asMap().entries.map((entry) {
                  final index = entry.key;
                  final field = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: field['name'],
                            decoration: InputDecoration(
                              labelText: 'اسم الحقل',
                              helperText: field['desc'],
                            ),
                            onChanged: (v) {
                              _dbFieldsWithDesc[index]['name'] = v.trim();
                              _loadColumnDescriptions();
                              _resetMapping();
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: field['desc'],
                            decoration: const InputDecoration(labelText: 'وصف الحقل'),
                            onChanged: (v) {
                              _dbFieldsWithDesc[index]['desc'] = v;
                              _loadColumnDescriptions();
                              setState(() {});
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _dbFieldsWithDesc.removeAt(index);
                              _loadColumnDescriptions();
                              _resetMapping();
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _dbFieldsWithDesc.add({'name': '', 'desc': ''});
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة حقل'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _dbFieldsWithDesc = List.from(defaultDbFieldsWithDesc);
                      _loadColumnDescriptions();
                      _resetMapping();
                    });
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('استعادة الافتراضية'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewAndImportButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isPreviewLoading ? null : _loadPreview,
            icon: _isPreviewLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.preview),
            label: const Text('معاينة البيانات'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isImporting ? null : _startImport,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('بدء الاستيراد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معاينة أول 5 صفوف:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  columns: _previewRows.isNotEmpty
                      ? _previewRows.first.keys.map((key) => DataColumn(label: Text(key))).toList()
                      : [],
                  rows: _previewRows.map((row) {
                    return DataRow(
                      cells: row.values.map((val) => DataCell(Text(val?.toString() ?? ''))).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: _progress, minHeight: 8, borderRadius: BorderRadius.circular(10)),
            const SizedBox(height: 12),
            Text('${(_progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip('جديد', _newItemsCount, Colors.green),
                _buildStatChip('تحديث', _updatedItemsCount, Colors.blue),
                _buildStatChip('أخطاء', _errorItemsCount, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _productBox.close();
    _importLogsBox.close();
    super.dispose();
  }
}

// فئة بسيطة لإلغاء العمليات
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}