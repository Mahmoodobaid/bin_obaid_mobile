import 'dart:io';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/permission_service.dart';

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});
  @override
  ConsumerState<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen> {
  File? _file;
  List<String> _cols = [];
  Map<String, String?> _map = {'sku': null, 'name': null, 'unit_price': null, 'stock_quantity': null};
  double _progress = 0;
  bool _uploading = false;
  int _headerRowIndex = 0;

  Future<void> _pick() async {
    await PermissionService.requestStorage(context);
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _cols = [];
        _map.updateAll((_, __) => null);
      });
      _read();
    }
  }

  void _read() async {
    final bytes = await _file!.readAsBytes();
    final excel = excel_lib.Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    if (_headerRowIndex >= rows.length) _headerRowIndex = 0;
    setState(() {
      _cols = rows[_headerRowIndex].map((c) => c?.value.toString() ?? '').where((e) => e.isNotEmpty).toList();
    });
  }

  Future<void> _uploadAll() async {
    if (_file == null || _map.values.any((v) => v == null)) return;
    setState(() { _uploading = true; _progress = 0; });
    final bytes = await _file!.readAsBytes();
    final excel = excel_lib.Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rows = sheet.rows.skip(_headerRowIndex + 1).toList();
    final api = ref.read(apiServiceProvider);
    final batch = <Map<String, dynamic>>[];
    for (int i = 0; i < rows.length; i++) {
      final item = <String, dynamic>{};
      for (var entry in _map.entries) {
        if (entry.value == null) continue;
        final idx = _cols.indexOf(entry.value!);
        if (idx != -1 && idx < rows[i].length) {
          item[entry.key] = rows[i][idx]?.value;
        }
      }
      if (item['sku'] != null) batch.add(item);
      if (batch.length >= 20 || i == rows.length - 1) {
        await api.importProductsBatch(batch);
        batch.clear();
      }
      setState(() => _progress = (i + 1) / rows.length);
    }
    setState(() => _uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاستيراد')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('استيراد من Excel')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(children: [Expanded(child: Text(_file?.path.split('/').last ?? 'لم يتم اختيار ملف')), ElevatedButton(onPressed: _pick, child: const Text('استعراض'))]),
              if (_cols.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: (_headerRowIndex + 1).toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'رقم صف العناوين'),
                  onChanged: (v) { _headerRowIndex = (int.tryParse(v) ?? 1) - 1; _read(); },
                ),
                const SizedBox(height: 16),
                ..._map.keys.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<String>(
                    value: _map[f],
                    decoration: InputDecoration(labelText: f),
                    items: _cols.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _map[f] = v),
                  ),
                )),
                const SizedBox(height: 24),
                if (_uploading) LinearProgressIndicator(value: _progress),
                ElevatedButton(onPressed: _uploading ? null : _uploadAll, child: const Text('رفع للخادم')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
