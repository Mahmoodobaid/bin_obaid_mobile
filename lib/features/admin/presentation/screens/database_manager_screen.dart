import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

// -------------------------------------------------------------------------
// 1. الإعدادات الاحترافية (استخدام مفتاح الصلاحيات الكاملة)
// -------------------------------------------------------------------------
class BinObaidConfig {
  static const String url = "https://ackxfnznrjufhppaznjd.supabase.co";
  // تم اعتماد مفتاح Service Role لضمان جلب البيانات من كافة الجداول
  static const String serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY";
}

// -------------------------------------------------------------------------
// 2. محرك إدارة الحالة والتقارير المتقدمة
// -------------------------------------------------------------------------
class DatabaseState {
  final List<String> tables;
  final List<Map<String, dynamic>> data;
  final bool isLoading;
  final String? errorReport; // تقرير مفصل للخطأ

  DatabaseState({
    this.tables = const [], 
    this.data = const [], 
    this.isLoading = false, 
    this.errorReport
  });

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

  // إنشاء عميل Supabase باستخدام مفتاح الصلاحيات العليا
  final _adminClient = SupabaseClient(BinObaidConfig.url, BinObaidConfig.serviceKey);

  Future<void> initSystem() async {
    state = state.copyWith(isLoading: true);
    const activeTables = [
      'products', 'users', 'pending_users', 'quotes', 
      'quote_items', 'logs', 'settings', 'sync_queue'
    ];
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(tables: activeTables, isLoading: false);
  }

  Future<void> fetchTableData(String tableName) async {
    state = state.copyWith(isLoading: true, data: [], errorReport: null);
    try {
      final response = await _adminClient
          .from(tableName)
          .select()
          .order('created_at', ascending: false)
          .limit(500);
      
      state = state.copyWith(
        data: List<Map<String, dynamic>>.from(response), 
        isLoading: false
      );
    } catch (e) {
      String report = "تقرير تحليل المشكلة:\n";
      if (e.toString().contains("401")) report += "• خطأ في المصادقة (Key Invalid)";
      else if (e.toString().contains("404")) report += "• الجدول غير موجود في قاعدة البيانات";
      else if (e.toString().contains("SocketException")) report += "• لا يوجد اتصال بالإنترنت";
      else report += "• خطأ تقني: ${e.toString()}";
      
      state = state.copyWith(isLoading: false, errorReport: report);
    }
  }
}

final databaseProvider = StateNotifierProvider<DatabaseNotifier, DatabaseState>((ref) => DatabaseNotifier());

// -------------------------------------------------------------------------
// 3. الواجهة الرسومية النهائية (The Ultra UI v2.0)
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

    final filteredData = state.data.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(_query.toLowerCase()));
    }).toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        drawer: size.width <= 1100 ? Drawer(child: _buildSidePanel(state, isDark, isDrawer: true)) : null,
        body: Row(
          children: [
            if (size.width > 1100) _buildSidePanel(state, isDark),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(isDark),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _currentTable == null 
                        ? _buildWelcomeDashboard(isDark)
                        : _buildMainContentArea(filteredData, state, isDark),
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

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width <= 1100)
            IconButton(icon: const Icon(Icons.menu_open_rounded, color: Colors.blue), onPressed: () => Scaffold.of(context).openDrawer()),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_currentTable == null ? "نظرة عامة" : "إدارة ${_currentTable!.toUpperCase()}", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text(DateTime.now().toString().split(' ')[0], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const Spacer(),
          _buildSearchField(isDark),
          const SizedBox(width: 20),
          _buildIconButton(Icons.refresh_rounded, () => _currentTable != null ? ref.read(databaseProvider.notifier).fetchTableData(_currentTable!) : null),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      width: 320,
      height: 45,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'البحث السريع في البيانات...',
          prefixIcon: Icon(Icons.search_rounded, color: Colors.blue, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSidePanel(DatabaseState state, bool isDark, {bool isDrawer = false}) {
    return Container(
      width: 300,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 50),
          const CircleAvatar(radius: 35, backgroundColor: Colors.blue, child: Icon(Icons.bolt_rounded, color: Colors.white, size: 40)),
          const SizedBox(height: 15),
          const Text('Bin Obaid Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const Text('V2.0.0 PREMIUM', style: TextStyle(color: Colors.blue, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: state.tables.length,
              itemBuilder: (context, index) {
                final table = state.tables[index];
                final isSelected = _currentTable == table;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? Colors.blue.withOpacity(0.15) : Colors.transparent,
                  ),
                  child: ListTile(
                    leading: Icon(Icons.layers_outlined, color: isSelected ? Colors.blue : Colors.white24),
                    title: Text(table.toUpperCase(), style: TextStyle(color: isSelected ? Colors.blue : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? Container(width: 5, height: 20, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10))) : null,
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
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
          _buildLogoutTile(),
        ],
      ),
    );
  }

  Widget _buildMainContentArea(List<Map<String, dynamic>> data, DatabaseState state, bool isDark) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: Colors.blue));
    
    if (state.errorReport != null) {
      return _buildErrorState(state.errorReport!);
    }

    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final columns = data.first.keys.toList();

    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blue.withOpacity(0.1))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: PaginatedDataTable(
            header: Row(
              children: [
                const Icon(Icons.storage_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Text("قائمة سجلات ${_currentTable!.toUpperCase()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 13)))).toList(),
            source: _TableSource(data, context),
            rowsPerPage: _rowsPerPage,
            onRowsPerPageChanged: (val) => setState(() => _rowsPerPage = val!),
            showCheckboxColumn: false,
            columnSpacing: 40,
            horizontalMargin: 25,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String report) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.report_problem_rounded, color: Colors.red, size: 80),
            const SizedBox(height: 20),
            const Text("تعذر جلب البيانات من السحابة", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 15),
            Text(report, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => ref.read(databaseProvider.notifier).fetchTableData(_currentTable!),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              child: const Text("إعادة المحاولة الآن"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text("جدول ${_currentTable!.toUpperCase()} فارغ", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("لا توجد سجلات حالية في قاعدة البيانات لهذا التصنيف.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildWelcomeDashboard(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("مرحباً محمود علي عبيد 👋", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 10),
          const Text("نظام الإدارة المتكامل لمؤسسة بن عبيد جاهز للعمل بكامل صلاحيات المسؤول.", style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 40),
          Row(
            children: [
              _buildStatCard("إجمالي الجداول", "8", Icons.grid_view_rounded, Colors.blue),
              const SizedBox(width: 20),
              _buildStatCard("حالة النظام", "متصل", Icons.cloud_done_rounded, Colors.green),
              const SizedBox(width: 20),
              _buildStatCard("الصلاحية", "Admin", Icons.verified_user_rounded, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 20),
            Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, color: Colors.blue, size: 22), onPressed: onTap),
    );
  }

  Widget _buildLogoutTile() {
    return ListTile(
      leading: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
      title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white70)),
      onTap: () {},
    );
  }
}

// -------------------------------------------------------------------------
// 4. محرك معالجة البيانات الذكي والمفصل
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
      onSelectChanged: (_) => _showDetailedView(row),
      cells: row.values.map((v) => DataCell(
        Text(v?.toString() ?? "---", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))
      )).toList(),
    );
  }

  void _showDetailedView(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.info_outline_rounded, color: Colors.white)),
                  const SizedBox(width: 15),
                  const Text("تفاصيل السجل الكاملة", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                children: row.entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 11, letterSpacing: 1)),
                      const SizedBox(height: 5),
                      SelectableText(e.value?.toString() ?? "قيمة غير محددة", style: const TextStyle(fontSize: 16, height: 1.5)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(30),
              child: SizedBox(
                width: double.infinity, 
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context), 
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("العودة للقائمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
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
