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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: isDark ? const Color(0xFF1E1E2F) : Colors.grey.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'معلومات الاتصال',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppConfig.supabaseUrl,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Project: ackxfnznrjufhppaznjd',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
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
                                  title: Text(
                                    table,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  selected: _selectedTable == table,
                                  selectedTileColor: isDark
                                      ? Colors.blueGrey.shade800
                                      : Colors.blue.shade50,
                                  onTap: () => _selectTable(table),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            // منطقة عرض البيانات
            Expanded(
              child: _selectedTable == null
                  ? Center(
                      child: Text(
                        'اختر جدولاً من القائمة لعرض البيانات',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // شريط التحكم
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Chip(
                                label: Text(
                                  _selectedTable!,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _limitController,
                                  decoration: InputDecoration(
                                    labelText: 'الحد',
                                    labelStyle: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  onSubmitted: (_) => _refresh(),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.refresh,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                onPressed: _refresh,
                              ),
                            ],
                          ),
                        ),
                        // عرض البيانات
                        Expanded(
                          child: _buildDataView(state, isDark),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataView(DatabaseManagerState state, bool isDark) {
    if (state.isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.data.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات في هذا الجدول',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    final columns = state.data.first.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          isDark ? Colors.blueGrey.shade800 : Colors.blue.shade50,
        ),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        columns: columns
            .map(
              (col) => DataColumn(
                label: Text(
                  col,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
        rows: state.data.map((row) {
          return DataRow(
            cells: columns.map((col) {
              final value = row[col]?.toString() ?? '';
              return DataCell(
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
