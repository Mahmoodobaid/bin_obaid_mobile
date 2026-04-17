import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../services/api_service.dart';

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});
  @override
  ConsumerState<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen> {
  File? _file;
  List<String> _excelColumns = [];
  Map<String, String?> _mapping = {'sku': null, 'name': null, 'price': null};
  double _progress = 0;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _excelColumns = [];
        _mapping.updateAll((_, __) => null);
      });
      _readColumns();
    }
  }

  void _readColumns() async {
    final bytes = await _file!.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final headers = sheet.rows.first.map((c) => c?.value.toString() ?? '').toList();
    setState(() => _excelColumns = headers);
  }

  Future<void> _startUpload() async {
    if (_file == null || _mapping.values.any((v) => v == null)) return;
    setState(() {
      _isUploading = true;
      _progress = 0;
    });
    final bytes = await _file!.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rows = sheet.rows.skip(1).toList();
    final api = ref.read(apiServiceProvider);
    final batch = <Map<String, dynamic>>[];

    for (int i = 0; i < rows.length; i++) {
      final item = <String, dynamic>{};
      for (var entry in _mapping.entries) {
        final colIndex = _excelColumns.indexOf(entry.value!);
        if (colIndex != -1) item[entry.key] = rows[i][colIndex]?.value;
      }
      if (item['sku'] != null) batch.add(item);
      if (batch.length >= 20 || i == rows.length - 1) {
        await api.importProductsBatch(batch);
        batch.clear();
      }
      setState(() => _progress = (i + 1) / rows.length);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاستيراد بنجاح')));
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('استيراد الأصناف من Excel')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(_file?.path.split('/').last ?? 'لم يتم اختيار ملف')),
                  ElevatedButton(onPressed: _pickFile, child: const Text('استعراض')),
                ],
              ),
              const SizedBox(height: 24),
              if (_excelColumns.isNotEmpty) ...[
                Table(
                  border: TableBorder.all(),
                  children: [
                    const TableRow(children: [Text('حقل قاعدة البيانات'), Text('عمود Excel')]),
                    ..._mapping.keys.map((field) => TableRow(children: [
                      Text(field),
                      DropdownButton<String>(
                        value: _mapping[field],
                        items: _excelColumns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _mapping[field] = v),
                      ),
                    ])),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isUploading) LinearProgressIndicator(value: _progress),
                ElevatedButton(
                  onPressed: _isUploading ? null : _startUpload,
                  child: const Text('رفع التحديثات للخادم'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
