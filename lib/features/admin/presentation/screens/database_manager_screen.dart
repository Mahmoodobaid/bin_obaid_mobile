import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// -------------------------------------------------------------------------
// 1. إعدادات الاتصال المباشرة (نظام بن عبيد - إب)
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
    // الجداول الفعلية المكتشفة في نظامك
    const activeTables = [
      'products', 'users', 'pending_users', 'quotes', 
      'quote_items', 'logs', 'settings', 'sync_queue'
    ];
    await Future.delayed(const Duration(milliseconds: 800)); // مظهر احترافي للتحميل
    state = state.copyWith(tables: activeTables, isLoading: false);
  }

  Future<void> fetchTableData(String tableName) async {
    state = state.copyWith(isLoading: true, data: [], error: null);
    try {
      final response = await _supabase.from(tableName).select().limit(500); // جلب كمية كافية
      state = state.copyWith(data: List<Map<String, dynamic>>.from(response), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final databaseProvider = StateNotifierProvider<DatabaseNotifier, DatabaseState>((ref) => DatabaseNotifier());

// -------------------------------------------------------------------------
// 3. الواجهة الرسومية الاحترافية (The Professional UI)
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
  int _rowsPerPage = 10;

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

    // تصفية البيانات ذكياً
    final filteredData = state.data.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(_query.toLowerCase()));
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Row(
          children: [
            // القائمة الجانبية (Navigation Side Panel)
            if (size.width > 700) _buildSidePanel(state, isDark),
            
            Expanded(
              child: Column(
                children: [
                  _buildTopHeader(isDark, context),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _currentTable == null 
                        ? _buildDashboardHome(isDark)
                        : _buildMainDataTable(filteredData, isDark, state.isLoading),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // زر القائمة للجوال
        drawer: size.width <= 700 ? Drawer(child: _buildSidePanel(state, isDark)) : null,
      ),
    );
  }

  Widget _buildTopHeader(bool isDark, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width <= 700)
            Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
          const Text('نظام بن عبيد السحابي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          _buildSearchField(isDark),
          const SizedBox(width: 15),
          IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.redAccent), onPressed: () => context.go('/home')),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      width: 300,
      height: 45,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'بحث سريع في السجلات...',
          prefixIcon: Icon(Icons.search, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSidePanel(DatabaseState state, bool isDark) {
    return Container(
      width: 260,
      color: isDark ? const Color(0xFF161B22) : Colors.blue.shade900,
      child: Column(
        children: [
          const SizedBox(height: 50),
          const CircleAvatar(radius: 35, backgroundColor: Colors.white24, child: Icon(Icons.business_center, color: Colors.white, size: 35)),
          const SizedBox(height: 15),
          const Text('Bin Obaid Trading', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Text('لوحة الإدارة v2.0', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 30),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView.builder(
              itemCount: state.tables.length,
              itemBuilder: (context, index) {
                final table = state.tables[index];
                final isSelected = _currentTable == table;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.white.withOpacity(0.1),
                  leading: Icon(Icons.grid_view_rounded, color: isSelected ? Colors.amber : Colors.white70),
                  title: Text(table.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  onTap: () {
                    setState(() => _currentTable = table);
                    ref.read(databaseProvider.notifier).fetchTableData(table);
                    if (MediaQuery.of(context).size.width <= 700) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDataTable(List<Map<String, dynamic>> data, bool isDark, bool isLoading) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (data.isEmpty) return const Center(child: Text('لا توجد بيانات متاحة حالياً'));

    final columns = data.first.keys.toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      child: Theme(
        data: Theme.of(context).copyWith(cardTheme: const CardTheme(elevation: 0)),
        child: SingleChildScrollView(
          child: PaginatedDataTable(
            header: Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.blue),
                const SizedBox(width: 10),
                Text('سجلات جدول ${_currentTable?.toUpperCase()}'),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.read(databaseProvider.notifier).fetchTableData(_currentTable!)),
            ],
            columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)))).toList(),
            source: _TableSource(data, context),
            rowsPerPage: _rowsPerPage,
            onRowsPerPageChanged: (val) => setState(() => _rowsPerPage = val!),
            availableRowsPerPage: const [10, 20, 50],
            columnSpacing: 40,
            horizontalMargin: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHome(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.analytics_outlined, size: 100, color: isDark ? Colors.white12 : Colors.grey[200]),
        const SizedBox(height: 20),
        const Text('أهلاً بك يا سيد محمود', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('اختر أحد الجداول من القائمة اليمنى لإدارة بيانات المتجر والعملاء', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}

// -------------------------------------------------------------------------
// 4. محرك البيانات المتقدم (Data Engine)
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
      onSelectChanged: (selected) => _openAdvancedDetail(row),
      cells: row.values.map((v) => DataCell(Text(v.toString(), maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
    );
  }

  void _openAdvancedDetail(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('تفاصيل السجل بدقة عالية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: row.entries.map((e) => ListTile(
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                  subtitle: SelectableText(e.value.toString(), style: const TextStyle(fontSize: 16)),
                  trailing: IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () {
                    Clipboard.setData(ClipboardData(text: e.value.toString()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النص بنجاح!'), behavior: SnackBarBehavior.floating));
                  }),
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('إغلاق التفاصيل'))),
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
