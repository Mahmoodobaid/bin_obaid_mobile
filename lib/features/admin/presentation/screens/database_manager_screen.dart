import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/database_manager_provider.dart';
import '../../../../core/config/config.dart';

class DatabaseManagerScreen extends ConsumerStatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  ConsumerState<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends ConsumerState<DatabaseManagerScreen> {
  String? _selectedTable;
  final _limitController = TextEditingController(text: '50');
  bool _showDrawer = true; // التحكم في إظهار/إخفاء القائمة الجانبية

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseManagerProvider.notifier).loadTables();
    });
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _selectTable(String table) {
    setState(() {
      _selectedTable = table;
      _showDrawer = false; // إخفاء القائمة عند اختيار جدول
    });
    ref.read(databaseManagerProvider.notifier).loadTableData(
      table: table,
      limit: int.parse(_limitController.text),
    );
  }

  void _toggleDrawer() {
    setState(() {
      _showDrawer = !_showDrawer;
    });
  }

  void _refresh() {
    if (_selectedTable != null) {
      ref.read(databaseManagerProvider.notifier).loadTableData(
        table: _selectedTable!,
        limit: int.parse(_limitController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(databaseManagerProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مدير قاعدة البيانات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
            tooltip: 'العودة للرئيسية',
          ),
          actions: [
            if (_selectedTable != null)
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: _toggleDrawer,
                tooltip: 'إظهار/إخفاء قائمة الجداول',
              ),
          ],
        ),
        body: Row(
          children: [
            // القائمة الجانبية (تظهر/تختفي حسب _showDrawer)
            if (_showDrawer)
              Container(
                width: 280,
                color: Colors.grey.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('معلومات الاتصال', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(AppConfig.supabaseUrl, style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 4),
                          const Text('Project: ackxfnznrjufhppaznjd', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: state.isLoadingTables
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: state.tables.length,
                              itemBuilder: (_, i) {
                                final table = state.tables[i];
                                return ListTile(
                                  title: Text(table),
                                  selected: _selectedTable == table,
                                  onTap: () => _selectTable(table),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            // منطقة عرض البيانات (تتمدد لملء المساحة المتبقية)
            Expanded(
              child: _selectedTable == null
                  ? const Center(child: Text('اختر جدولاً من القائمة لعرض البيانات'))
                  : Column(
                      children: [
                        // شريط التحكم (الحد والتحديث)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Chip(label: Text(_selectedTable!, style: const TextStyle(fontWeight: FontWeight.bold))),
                              const Spacer(),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _limitController,
                                  decoration: const InputDecoration(labelText: 'الحد'),
                                  onSubmitted: (_) => _refresh(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _refresh,
                              ),
                            ],
                          ),
                        ),
                        // عرض البيانات
                        Expanded(
                          child: _buildDataView(state),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataView(DatabaseManagerState state) {
    if (state.isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.data.isEmpty) {
      return const Center(child: Text('لا توجد بيانات في هذا الجدول'));
    }

    final columns = state.data.first.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
        rows: state.data.map((row) {
          return DataRow(
            cells: columns.map((col) {
              final value = row[col]?.toString() ?? '';
              return DataCell(
                Text(value),
                onTap: () => _showEditDialog(row),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بيانات السجل'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: row.entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
