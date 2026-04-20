import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/config/config.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/permission_service.dart';

const List<String> defaultDbFields = [
  'sku',
  'barcode',
  'name',
  'description',
  'category',
  'unit',
  'unit_price',
  'wholesale_price',
  'stock_quantity',
  'min_stock',
  'location',
  'notes',
];

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  ConsumerState<ImportProductsScreen> createState() =>
      _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedFile;
  List<String> _excelColumns = [];
  List<String> _sheetNames = [];
  String _selectedSheet = '';

  List<String> _dbFields = List.from(defaultDbFields);
  Map<String, String?> _columnMapping = {};
  int _headerRowIndex = 0;

  String _quantityMergeOption = 'add';
  bool _updateExistingOnly = false;

  bool _isLoadingFile = false;
  bool _isImporting = false;
  bool _hasInternet = false;
  bool _isPreviewLoading = false;
  List<Map<String, dynamic>> _previewRows = [];

  double _progress = 0;
  String _statusMessage = 'جاهز للاستيراد';

  int _newItemsCount = 0;
  int _updatedItemsCount = 0;
  int _skippedItemsCount = 0;
  int _errorItemsCount = 0;
  final List<String> _errorLogs = [];

  late Box _productBox;
  late Box _importLogsBox;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkInternet();
    await _loadSavedSettings();
    _productBox = await Hive.openBox('products');
    _importLogsBox = await Hive.openBox('import_logs');
    _resetMapping();
    if (mounted) setState(() {});
  }

  Future<void> _checkInternet() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _hasInternet = connectivity != ConnectivityResult.none);
    }
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHeaderRow = prefs.getInt('excel_header_row');
    final savedMapping = prefs.getString('excel_column_mapping');
    final savedFields = prefs.getStringList('excel_db_fields');
    final savedQuantityOption = prefs.getString('excel_quantity_option');
    final savedUpdateOnly = prefs.getBool('excel_update_only');

    if (savedHeaderRow != null) _headerRowIndex = savedHeaderRow;
    if (savedFields != null && savedFields.isNotEmpty) {
      _dbFields = savedFields;
    }
    if (savedQuantityOption != null) _quantityMergeOption = savedQuantityOption;
    if (savedUpdateOnly != null) _updateExistingOnly = savedUpdateOnly;

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
    await prefs.setString('excel_column_mapping', jsonEncode(_columnMapping));
    await prefs.setStringList('excel_db_fields', _dbFields);
    await prefs.setString('excel_quantity_option', _quantityMergeOption);
    await prefs.setBool('excel_update_only', _updateExistingOnly);
  }

  void _resetMapping() {
    _columnMapping = {for (var f in _dbFields) f: null};
  }

  Future<void> _pickExcelFile() async {
    try {
      setState(() => _isLoadingFile = true);
      await PermissionService.requestStorage(context);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.single.path == null) {
        if (mounted) setState(() => _isLoadingFile = false);
        return;
      }
      _selectedFile = File(result.files.single.path!);
      final bytes = await _selectedFile!.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      _sheetNames = excel.tables.keys.toList();
      if (_sheetNames.isEmpty) {
        throw Exception('ملف Excel لا يحتوي على أي أوراق');
      }
      _selectedSheet = _sheetNames.first;
      await _loadColumnsFromExcel();
      if (mounted) setState(() => _isLoadingFile = false);
    } catch (e) {
      if (mounted) setState(() => _isLoadingFile = false);
      _showError('حدث خطأ أثناء قراءة ملف Excel: $e');
    }
  }

  Future<void> _loadColumnsFromExcel() async {
    if (_selectedFile == null) return;
    try {
      final bytes = await _selectedFile!.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[_selectedSheet];
      if (sheet == null || sheet.rows.isEmpty) return;
      if (_headerRowIndex >= sheet.rows.length) _headerRowIndex = 0;
      final headerRow = sheet.rows[_headerRowIndex];
      _excelColumns = headerRow
          .map((cell) => _cleanText(cell?.value))
          .where((e) => e.isNotEmpty)
          .toList();
      if (mounted) setState(() {});
    } catch (e) {
      _showError('تعذر تحميل الأعمدة: $e');
    }
  }

  String _cleanText(dynamic value) {
    return value?.toString().replaceAll('\n', ' ').replaceAll('\r', ' ').trim() ?? '';
  }

  Future<void> _loadPreview() async {
    if (_selectedFile == null) return;
    setState(() => _isPreviewLoading = true);
    try {
      final bytes = await _selectedFile!.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[_selectedSheet];
      if (sheet == null) return;
      final rows = sheet.rows.skip(_headerRowIndex + 1).take(5).toList();
      final preview = <Map<String, dynamic>>[];
      for (final row in rows) {
        final item = <String, dynamic>{};
        for (final entry in _columnMapping.entries) {
          if (entry.value == null) continue;
          final idx = _excelColumns.indexOf(entry.value!);
          if (idx != -1 && idx < row.length) {
            item[entry.key] = _cleanText(row[idx]?.value);
          }
        }
        preview.add(item);
      }
      setState(() => _previewRows = preview);
    } catch (e) {
      _showError('فشل تحميل المعاينة: $e');
    } finally {
      if (mounted) setState(() => _isPreviewLoading = false);
    }
  }

  Future<void> _startImport() async {
    if (_selectedFile == null) {
      _showError('يرجى اختيار ملف Excel أولاً');
      return;
    }
    if (_columnMapping['sku'] == null && _columnMapping['barcode'] == null) {
      _showError('يجب ربط حقل SKU أو Barcode على الأقل');
      return;
    }
    await _saveSettings();
    if (!mounted) return;
    setState(() {
      _isImporting = true;
      _progress = 0;
      _newItemsCount = 0;
      _updatedItemsCount = 0;
      _skippedItemsCount = 0;
      _errorItemsCount = 0;
      _errorLogs.clear();
      _statusMessage = 'جاري تحليل البيانات...';
    });

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[_selectedSheet];
      if (sheet == null) throw Exception('تعذر العثور على الورقة المحددة');
      final rows = sheet.rows.skip(_headerRowIndex + 1).toList();
      final apiService = ref.read(apiServiceProvider);
      final List<Map<String, dynamic>> pendingServerSync = [];
      final int totalRows = rows.length;

      for (int rowIndex = 0; rowIndex < totalRows; rowIndex++) {
        if (!mounted) return;
        try {
          final row = rows[rowIndex];
          final product = <String, dynamic>{};
          for (final entry in _columnMapping.entries) {
            if (entry.value == null) continue;
            final idx = _excelColumns.indexOf(entry.value!);
            if (idx == -1 || idx >= row.length) continue;
            final rawValue = row[idx]?.value;
            product[entry.key] = _convertValue(entry.key, rawValue);
          }
          String? sku = product['sku']?.toString().trim();
          if (sku == null || sku.isEmpty) {
            sku = product['barcode']?.toString().trim();
          }
          if (sku == null || sku.isEmpty) {
            _skippedItemsCount++;
            continue;
          }
          final existing = _productBox.get(sku);

          // --- المنطق المصحح ---
          if (existing != null) {
            // المنتج موجود مسبقاً - نقوم بتحديثه دائماً (بغض النظر عن _updateExistingOnly)
            final updated = Map<String, dynamic>.from(existing);
            updated.addAll(product);

            if (_quantityMergeOption == 'add') {
              final oldQty = _toDouble(existing['stock_quantity']);
              final newQty = _toDouble(product['stock_quantity']);
              updated['stock_quantity'] = oldQty + newQty;
            } else if (_quantityMergeOption == 'replace') {
              // الاحتفاظ بالكمية الجديدة فقط
            } else {
              // تجاهل تغيير الكمية
              updated['stock_quantity'] = existing['stock_quantity'];
            }
            updated['updated_at'] = DateTime.now().toIso8601String();
            updated['sync_status'] = 'pending';
            await _productBox.put(sku, updated);
            pendingServerSync.add(updated);
            _updatedItemsCount++;
          } else {
            // منتج جديد
            if (_updateExistingOnly) {
              // الخيار مفعّل: نتجاهل المنتجات الجديدة
              _skippedItemsCount++;
            } else {
              // إضافة المنتج الجديد
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
        setState(() {
          _progress = (rowIndex + 1) / totalRows;
          _statusMessage = 'معالجة ${rowIndex + 1} من $totalRows';
        });
        await Future.delayed(const Duration(milliseconds: 5));
      }

      if (_hasInternet && pendingServerSync.isNotEmpty) {
        setState(() => _statusMessage = 'مزامنة مع الخادم...');
        const batchSize = 20;
        for (int i = 0; i < pendingServerSync.length; i += batchSize) {
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
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      await _importLogsBox.add({
        'file_name': _selectedFile?.path.split('/').last,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تقرير الاستيراد'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reportItem('جديد', _newItemsCount, Colors.green),
              _reportItem('محدث', _updatedItemsCount, Colors.blue),
              _reportItem('متجاهل', _skippedItemsCount, Colors.orange),
              _reportItem('أخطاء', _errorItemsCount, Colors.red),
              if (_errorLogs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('سجل الأخطاء:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _errorLogs.length,
                    itemBuilder: (c, i) => Text(_errorLogs[i], style: const TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _errorLogs.join('\n')));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الأخطاء')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('نسخ الأخطاء'),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  Widget _reportItem(String title, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: color.withOpacity(0.15), child: Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
    );
  }

  Future<void> _exportErrorLog() async {
    await Clipboard.setData(ClipboardData(text: _errorLogs.join('\n')));
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

  Widget _buildFieldEditor() {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        title: const Text('تخصيص حقول قاعدة البيانات'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._dbFields.asMap().entries.map((e) {
                  final index = e.key;
                  final field = e.value;
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: field,
                          decoration: InputDecoration(labelText: 'حقل ${index + 1}'),
                          onChanged: (v) {
                            _dbFields[index] = v.trim();
                            _resetMapping();
                            setState(() {});
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _dbFields.removeAt(index);
                            _resetMapping();
                          });
                        },
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _dbFields.add('');
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة حقل'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _saveSettings();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ حقول قاعدة البيانات')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ الحقول'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _dbFields = List.from(defaultDbFields);
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          elevation: 0,
          title: const Text('استيراد المنتجات من Excel'),
          centerTitle: true,
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
          opacity: _animationController,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildFileSelector(),
              const SizedBox(height: 20),
              if (_excelColumns.isNotEmpty) ...[
                _buildSheetSelector(),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: (_headerRowIndex + 1).toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم صف العناوين',
                    prefixIcon: Icon(Icons.table_rows),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) async {
                    _headerRowIndex = (int.tryParse(v) ?? 1) - 1;
                    await _loadColumnsFromExcel();
                  },
                ),
                const SizedBox(height: 16),
                _buildMappingTable(),
                const SizedBox(height: 16),
                _buildOptions(),
                const SizedBox(height: 16),
                _buildFieldEditor(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isPreviewLoading ? null : _loadPreview,
                        icon: const Icon(Icons.preview),
                        label: const Text('معاينة'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isImporting ? null : _startImport,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('بدء الاستيراد'),
                      ),
                    ),
                  ],
                ),
                if (_previewRows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('معاينة أول 5 صفوف:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _previewRows.length,
                      itemBuilder: (c, i) => Container(
                        width: 250,
                        padding: const EdgeInsets.all(8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _previewRows[i].entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              if (_isImporting) ...[
                const SizedBox(height: 20),
                _buildProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedFile?.path.split('/').last ?? 'لم يتم اختيار ملف',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoadingFile ? null : _pickExcelFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('اختيار ملف'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasInternet
                  ? '🟢 متصل بالإنترنت - سيتم رفع البيانات للسيرفر'
                  : '🔴 غير متصل - حفظ محلي فقط',
              style: TextStyle(color: _hasInternet ? Colors.green : Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetSelector() {
    if (_sheetNames.length <= 1) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      value: _selectedSheet,
      decoration: const InputDecoration(
        labelText: 'ورقة العمل',
        border: OutlineInputBorder(),
      ),
      items: _sheetNames.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) async {
        setState(() => _selectedSheet = v!);
        await _loadColumnsFromExcel();
      },
    );
  }

  Widget _buildMappingTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ربط الأعمدة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._dbFields.where((f) => f.isNotEmpty).map((field) {
              final usedColumns = _columnMapping.values.where((v) => v != null).toSet();
              final availableColumns = _excelColumns.where((c) => !usedColumns.contains(c) || _columnMapping[field] == c).toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String>(
                  value: _columnMapping[field],
                  decoration: InputDecoration(
                    labelText: field,
                    border: const OutlineInputBorder(),
                  ),
                  items: availableColumns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _columnMapping[field] = v),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('خيارات الاستيراد', style: TextStyle(fontWeight: FontWeight.bold)),
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
            SwitchListTile(
              title: const Text('تحديث المنتجات الموجودة فقط (لا تضف منتجات جديدة)'),
              subtitle: const Text('عند التفعيل، يتم تحديث الموجود وتجاهل أي منتج جديد'),
              value: _updateExistingOnly,
              onChanged: (v) => setState(() => _updateExistingOnly = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: _progress, minHeight: 10, borderRadius: BorderRadius.circular(10)),
            const SizedBox(height: 12),
            Text('${(_progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_statusMessage),
          ],
        ),
      ),
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
