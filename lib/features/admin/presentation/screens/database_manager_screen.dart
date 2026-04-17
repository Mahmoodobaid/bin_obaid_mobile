import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseManagerProvider.notifier).loadTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(databaseManagerProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مدير قاعدة البيانات')),
        body: Row(
          children: [
            Container(
              width: 280,
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('معلومات الاتصال', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(AppConfig.supabaseUrl, style: const TextStyle(fontSize: 11)),
                        Text('Project: ackxfnznrjufhppaznjd'),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: state.isLoadingTables
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: state.tables.length,
                            itemBuilder: (_, i) => ListTile(
                              title: Text(state.tables[i]),
                              selected: _selectedTable == state.tables[i],
                              onTap: () {
                                setState(() => _selectedTable = state.tables[i]);
                                ref.read(databaseManagerProvider.notifier).loadTableData(
                                  table: _selectedTable!,
                                  limit: int.parse(_limitController.text),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _selectedTable == null
                  ? const Center(child: Text('اختر جدولاً من القائمة'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Chip(label: Text(_selectedTable!)),
                              const Spacer(),
                              SizedBox(width: 80, child: TextField(controller: _limitController)),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => ref.read(databaseManagerProvider.notifier).loadTableData(
                                  table: _selectedTable!,
                                  limit: int.parse(_limitController.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.isLoadingData) const Expanded(child: Center(child: CircularProgressIndicator())),
                        if (state.data.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: state.data.first.keys.map((c) => DataColumn(label: Text(c))).toList(),
                                rows: state.data.map((row) => DataRow(
                                  cells: row.values.map((v) => DataCell(Text(v.toString()))).toList(),
                                )).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
