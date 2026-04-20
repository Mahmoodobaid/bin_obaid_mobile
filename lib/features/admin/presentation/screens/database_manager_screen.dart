import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;

// -------------------------------------------------------------------------
// 1. إعدادات الاتصال المباشرة (نظام بن عبيد - الإصدار الاحترافي)
// -------------------------------------------------------------------------
class BinObaidConfig {
  static const String url = "https://ackxfnznrjufhppaznjd.supabase.co";
  static const String key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY";
}

// -------------------------------------------------------------------------
// 2. إدارة الحالة المتقدمة (State Management)
// -------------------------------------------------------------------------
class DatabaseState {
  final List<String> tables;
  final List<Map<String, dynamic>> data;
  final bool isLoading;
  final String? error;

  DatabaseState({this.tables = const [], this.data = const [], this.isLoading = false, this.error});

  DatabaseState copyWith({List<String>? tables, List<Map<String, dynamic>>? data, bool? isLoading, String? error}) {
    return DatabaseState(
      tables: tables ?? this.tables,
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DatabaseNotifier extends StateNotifier<DatabaseState> {
  DatabaseNotifier() : super(DatabaseState());

  final _supabase = SupabaseClient(BinObaidConfig.url, BinObaidConfig.key);

  Future<void> initSystem() async {
    state = state.copyWith(isLoading: true);
    // الجداول الأساسية المعتمدة في نظام بن عبيد
    const activeTables = [
      'products', 'users', 'pending_users', 'quotes', 
      'quote_items', 'logs', 'settings', 'sync_queue'
    ];
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(tables: activeTables, isLoading: false);
  }

  Future<void> fetchTableData(String tableName) async {
    state = state.copyWith(isLoading: true, data: [], error: null);
    try {
      final response = await _supabase.from(tableName).select().limit(1000);
      state = state.copyWith(
        data: List<Map<String, dynamic>>.from(response), 
        isLoading: false
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final databaseProvider = StateNotifierProvider<DatabaseNotifier, DatabaseState>((ref) => DatabaseNotifier());

// -------------------------------------------------------------------------
// 3. الواجهة الرسومية الاحترافية (The Ultra UI)
// -------------------------------------------------------------------------
class DatabaseManagerScreen extends ConsumerStatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  ConsumerState<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends ConsumerState<DatabaseManagerScreen> {
  String? _currentTable;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => ref.read(databaseProvider.notifier).initSystem());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(databaseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    // تصفية البيانات بشكل لحظي
    final filteredData = state.data.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(_query.toLowerCase()));
    }).toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        drawer: size.width <= 900 ? Drawer(child: _buildSidePanel(state, isDark, isDrawer: true)) : null,
        body: Row(
          children: [
            if (size.width > 900) _buildSidePanel(state, isDark),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _currentTable == null 
                        ? _buildWelcomeView(isDark)
                        : _buildDataTableArea(filteredData, isDark, state.isLoading),
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

  Widget _buildHeader(bool isDark) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width <= 900)
            Builder(builder: (context) => IconButton(
              icon: const Icon(Icons.menu_open_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            )),
          const SizedBox(width: 10),
          Text(
            _currentTable == null ? 'لوحة التحكم الرئيسية' : 'إدارة جدول ${_currentTable!.toUpperCase()}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _buildSearchBox(isDark),
          const SizedBox(width: 15),
          _buildActionIcon(Icons.notifications_none_rounded),
          _buildActionIcon(Icons.help_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Container(
      width: 300,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'بحث في السجلات...',
          prefixIcon: Icon(Icons.search, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 8),
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: IconButton(icon: Icon(icon, color: Colors.blue, size: 20), onPressed: () {}),
    );
  }

  Widget _buildSidePanel(DatabaseState state, bool isDark, {bool isDrawer = false}) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        boxShadow: [if (isDrawer) const BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Hero(
            tag: 'logo',
            child: CircleAvatar(
              radius: 40, 
              backgroundColor: Colors.blue, 
              child: Icon(Icons.bolt_rounded, color: Colors.white, size: 45)
            ),
          ),
          const SizedBox(height: 15),
          const Text('Bin Obaid Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const Text('نظام الإدارة السحابي v2.0', style: TextStyle(color: Colors.blue, fontSize: 12)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: state.tables.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final table = state.tables[index];
                final isSelected = _currentTable == table;
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    selected: isSelected,
                    selectedTileColor: Colors.blue.withOpacity(0.2),
                    leading: Icon(Icons.table_rows_rounded, color: isSelected ? Colors.blue : Colors.white38),
                    title: Text(
                      table.toUpperCase(), 
                      style: TextStyle(color: isSelected ? Colors.blue : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)
                    ),
                    onTap: () {
                      setState(() => _currentTable = table);
                      ref.read(databaseProvider.notifier).fetchTableData(table);
                      if (isDrawer) Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white38),
            title: const Text('الإعدادات', style: TextStyle(color: Colors.white70)),
            onTap: () {},
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDataTableArea(List<Map<String, dynamic>> data, bool isDark, bool isLoading) {
    if (isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (data.isEmpty) return const Center(child: Text('هذا الجدول لا يحتوي على بيانات حالياً'));

    final columns = data.first.keys.toList();

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: PaginatedDataTable(
            header: const Text('سجلات البيانات المستخرجة', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              ElevatedButton.icon(
                onPressed: () => ref.read(databaseProvider.notifier).fetchTableData(_currentTable!),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تحديث'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
            columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))).toList(),
            source: _TableSource(data, context),
            rowsPerPage: _rowsPerPage,
            onRowsPerPageChanged: (val) => setState(() => _rowsPerPage = val!),
            availableRowsPerPage: const [10, 20, 50],
            columnSpacing: 30,
            horizontalMargin: 20,
            showCheckboxColumn: false,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeView(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.dashboard_customize_rounded, size: 120, color: Colors.blue.withOpacity(0.2)),
        const SizedBox(height: 20),
        const Text('أهلاً بك يا سيد محمود بن عبيد', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('نظامك جاهز للعمل. اختر أحد الجداول من القائمة الجانبية لعرض وتعديل البيانات.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
      ],
    );
  }
}

// -------------------------------------------------------------------------
// 4. محرك معالجة البيانات (Smart Data Engine)
// -------------------------------------------------------------------------
class _TableSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final BuildContext context;
  _TableSource(this.data, this.context);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final row = data[index];
    return DataRow(
      onSelectChanged: (_) => _showDetails(row),
      cells: row.values.map((v) => DataCell(
        Text(v?.toString() ?? "---", maxLines: 1, overflow: TextOverflow.ellipsis)
      )).toList(),
    );
  }

  void _showDetails(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(25),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('تفاصيل السجل الكاملة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: row.entries.map((e) => Card(
                  elevation: 0,
                  color: Colors.grey.withOpacity(0.05),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                    subtitle: SelectableText(e.value?.toString() ?? "قيمة فارغة", style: const TextStyle(fontSize: 16)),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_all_rounded, size: 20), 
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: e.value.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ للحافظة!'), behavior: SnackBarBehavior.floating));
                      }
                    ),
                  ),
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text('إغلاق النافذة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ),
            )
          ],
        ),
      ),
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => data.length;
  @override int get selectedRowCount => 0;
}
