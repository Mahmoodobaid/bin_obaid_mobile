import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

// -------------------------------------------------------------------------
// 1. الإعدادات السحابية (نظام بن عبيد - الوصول الكامل)
// -------------------------------------------------------------------------
class BinObaidConfig {
  static const String url = "https://ackxfnznrjufhppaznjd.supabase.co";
  // تم استخدام Service Role Key لضمان جلب البيانات حتى لو كانت الـ RLS مفعلة
  static const String serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY";
}

// -------------------------------------------------------------------------
// 2. محرك إدارة الحالة المتقدم (State Management)
// -------------------------------------------------------------------------
class DatabaseState {
  final List<String> tables;
  final List<Map<String, dynamic>> data;
  final bool isLoading;
  final String? errorReport;

  DatabaseState({this.tables = const [], this.data = const [], this.isLoading = false, this.errorReport});

  DatabaseState copyWith({List<String>? tables, List<Map<String, dynamic>>? data, bool? isLoading, String? errorReport}) {
    return DatabaseState(
      tables: tables ?? this.tables,
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorReport: errorReport,
    );
  }
}

class DatabaseNotifier extends StateNotifier<DatabaseState> {
  DatabaseNotifier() : super(DatabaseState());

  // إنشاء عميل الإدارة (Admin Client)
  final _adminClient = SupabaseClient(BinObaidConfig.url, BinObaidConfig.serviceKey);

  Future<void> initSystem() async {
    state = state.copyWith(isLoading: true);
    // قائمة الجداول المعتمدة لنظام بن عبيد
    const activeTables = ['products', 'users', 'pending_users', 'quotes', 'quote_items', 'logs', 'settings', 'sync_queue'];
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(tables: activeTables, isLoading: false);
  }

  Future<void> fetchTableData(String tableName) async {
    state = state.copyWith(isLoading: true, data: [], errorReport: null);
    try {
      final response = await _adminClient
          .from(tableName)
          .select()
          .order('created_at', ascending: false) // ترتيب تنازلي للأحدث
          .limit(500);
      
      state = state.copyWith(data: List<Map<String, dynamic>>.from(response), isLoading: false);
    } catch (e) {
      String report = "فشل في مزامنة البيانات:\n";
      if (e.toString().contains("401")) report += "• صلاحيات المفتاح غير كافية أو منتهية.";
      else if (e.toString().contains("SocketException")) report += "• تعذر الوصول للسيرفر (تحقق من الإنترنت).";
      else report += "• تفاصيل تقنية: ${e.toString()}";
      
      state = state.copyWith(isLoading: false, errorReport: report);
    }
  }
}

final databaseProvider = StateNotifierProvider<DatabaseNotifier, DatabaseState>((ref) => DatabaseNotifier());

// -------------------------------------------------------------------------
// 3. الواجهة الرسومية الفاخرة (Premium Dashboard UI)
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
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredData = state.data.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(_query.toLowerCase()));
    }).toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        drawer: size.width <= 1100 ? Drawer(child: _buildSidePanel(state, true)) : null,
        body: Row(
          children: [
            if (size.width > 1100) _buildSidePanel(state, false),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentTable == null 
                        ? _buildWelcomeHome(isDark)
                        : _buildMainWorkspace(filteredData, state, isDark),
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
          if (MediaQuery.of(context).size.width <= 1100)
            IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.blue), onPressed: () => Scaffold.of(context).openDrawer()),
          const SizedBox(width: 10),
          Text(_currentTable == null ? "لوحة التحكم الرئيسية" : "إدارة جدول ${_currentTable!.toUpperCase()}", 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          _buildSearchBox(isDark),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return Container(
      width: 280,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'بحث سريع...',
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.blue),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 8),
        ),
      ),
    );
  }

  Widget _buildSidePanel(DatabaseState state, bool isDrawer) {
    return Container(
      width: 280,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 50),
          const CircleAvatar(radius: 35, backgroundColor: Colors.blue, child: Icon(Icons.bolt_rounded, color: Colors.white, size: 40)),
          const SizedBox(height: 15),
          const Text('Bin Obaid Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const Text('نظام الإدارة v2.0', style: TextStyle(color: Colors.blue, fontSize: 10)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: state.tables.length,
              itemBuilder: (context, index) {
                final table = state.tables[index];
                final isSelected = _currentTable == table;
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                  ),
                  child: ListTile(
                    leading: Icon(Icons.table_chart_outlined, color: isSelected ? Colors.blue : Colors.white38),
                    title: Text(table.toUpperCase(), style: TextStyle(color: isSelected ? Colors.blue : Colors.white70, fontSize: 13)),
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
          const ListTile(leading: Icon(Icons.settings, color: Colors.white38), title: Text("الإعدادات", style: TextStyle(color: Colors.white38))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMainWorkspace(List<Map<String, dynamic>> data, DatabaseState state, bool isDark) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: Colors.blue));
    
    if (state.errorReport != null) {
      return _buildErrorState(state.errorReport!);
    }

    if (data.isEmpty) return const Center(child: Text("لا توجد بيانات متاحة في هذا الجدول حالياً."));

    final columns = data.first.keys.toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: PaginatedDataTable(
            header: const Text("السجلات المكتشفة"),
            actions: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: () => ref.read(databaseProvider.notifier).fetchTableData(_currentTable!)),
            ],
            columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))).toList(),
            source: _TableSource(data, context),
            rowsPerPage: _rowsPerPage,
            onRowsPerPageChanged: (v) => setState(() => _rowsPerPage = v!),
            showCheckboxColumn: false,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHome(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_rounded, size: 80, color: Colors.blue.withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text("مرحباً بك يا محمود علي عبيد", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("اختر أحد الجداول من القائمة الجانبية لعرض البيانات والتحكم بها.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String report) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            const Text("حدث خطأ في المزامنة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            Text(report, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => ref.read(databaseProvider.notifier).fetchTableData(_currentTable!),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("إعادة المحاولة"),
            )
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// 4. محرك معالجة الصفوف والبيانات (Data Table Engine)
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
      cells: row.values.map((v) => DataCell(Text(v?.toString() ?? "---", maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
    );
  }

  void _showDetails(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(padding: EdgeInsets.all(20), child: Text("تفاصيل السجل الكاملة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue))),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: row.entries.map((e) => ListTile(
                  title: Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  subtitle: SelectableText(e.value?.toString() ?? "فارغ", style: const TextStyle(fontSize: 16, color: Colors.black87)),
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))),
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
