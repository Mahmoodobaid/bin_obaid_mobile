import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

// -------------------------------------------------------------------------
// 1. الإعدادات المركزية (مفتاح الإدارة المطلقة)
// -------------------------------------------------------------------------
class AppConfig {
  static const String supabaseUrl = 'https://ackxfnznrjufhppaznjd.supabase.co';
  static const String supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY';
}

// -------------------------------------------------------------------------
// 2. محرك إدارة البيانات والحالة (Database Engine)
// -------------------------------------------------------------------------
class DatabaseState {
  final List<String> tables;
  final List<Map<String, dynamic>> data;
  final bool isLoading;
  final String? errorReport;

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

  // إنشاء عميل مباشر بصلاحيات Service Role لتجاوز الـ RLS
  final _client = SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseServiceKey);

  Future<void> initializeSystem() async {
    state = state.copyWith(isLoading: true);
    // تعريف الجداول النشطة في نظام بن عبيد
    const activeTables = ['products', 'users', 'quotes', 'quote_items', 'logs', 'settings', 'sync_queue'];
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(tables: activeTables, isLoading: false);
  }

  Future<void> fetchTableData(String tableName) async {
    state = state.copyWith(isLoading: true, data: [], errorReport: null);
    try {
      final response = await _client
          .from(tableName)
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      
      state = state.copyWith(data: List<Map<String, dynamic>>.from(response), isLoading: false);
    } catch (e) {
      String msg = "خطأ في الاتصال بالسحابة:\n";
      if (e.toString().contains("Failed host lookup")) msg += "• تعذر الوصول للسيرفر (افحص الإنترنت أو الـ DNS).";
      else if (e.toString().contains("401")) msg += "• مفتاح الصلاحيات غير صالح أو منتهي.";
      else msg += "• تفاصيل: ${e.toString()}";
      
      state = state.copyWith(isLoading: false, errorReport: msg);
    }
  }
}

final databaseProvider = StateNotifierProvider<DatabaseNotifier, DatabaseState>((ref) => DatabaseNotifier());

// -------------------------------------------------------------------------
// 3. الواجهة الاحترافية (Ultra UI v2.5)
// -------------------------------------------------------------------------
class DatabaseManagerScreen extends ConsumerStatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  ConsumerState<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends ConsumerState<DatabaseManagerScreen> {
  String? _selectedTable;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => ref.read(databaseProvider.notifier).initializeSystem());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(databaseProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        drawer: isMobile ? Drawer(child: _buildSideMenu(state)) : null,
        body: Row(
          children: [
            if (!isMobile) _buildSideMenu(state),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(isMobile),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _selectedTable == null 
                        ? _buildDashboardHome() 
                        : _buildDataTableArea(state),
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

  Widget _buildHeader(bool isMobile) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          if (isMobile) IconButton(icon: const Icon(Icons.menu, color: Colors.blue), onPressed: () => Scaffold.of(context).openDrawer()),
          Text(_selectedTable == null ? "الرئيسية" : "جدول ${_selectedTable!.toUpperCase()}", 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          _buildSearchBar(),
          const SizedBox(width: 15),
          _buildHeaderAction(Icons.refresh, () {
            if (_selectedTable != null) ref.read(databaseProvider.notifier).fetchTableData(_selectedTable!);
          }),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 250,
      height: 40,
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchTerm = v),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          hintText: "بحث سريع...",
          hintStyle: TextStyle(color: Colors.white24),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.blue),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSideMenu(DatabaseState state) {
    return Container(
      width: 260,
      color: const Color(0xFF0B1222),
      child: Column(
        children: [
          const SizedBox(height: 50),
          const CircleAvatar(radius: 35, backgroundColor: Colors.blue, child: Icon(Icons.business_center, color: Colors.white, size: 35)),
          const SizedBox(height: 10),
          const Text("بن عبيد كـلاود", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("ADMIN ACCESS", style: TextStyle(color: Colors.blue, fontSize: 9, letterSpacing: 2)),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: state.tables.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, i) {
                final table = state.tables[i];
                final isSelected = _selectedTable == table;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: Icon(Icons.table_chart_outlined, color: isSelected ? Colors.blue : Colors.white24),
                  title: Text(table, style: TextStyle(color: isSelected ? Colors.blue : Colors.white70, fontSize: 14)),
                  onTap: () {
                    setState(() => _selectedTable = table);
                    ref.read(databaseProvider.notifier).fetchTableData(table);
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text("خروج", style: TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDataTableArea(DatabaseState state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: Colors.blue));
    if (state.errorReport != null) return _buildErrorView(state.errorReport!);
    if (state.data.isEmpty) return const Center(child: Text("الجدول فارغ", style: TextStyle(color: Colors.white38)));

    final filteredData = state.data.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(_searchTerm.toLowerCase()));
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          color: const Color(0xFF1E293B),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.blue.withOpacity(0.1)),
                columns: filteredData.first.keys.map((key) => DataColumn(
                  label: Text(key.toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))
                )).toList(),
                rows: filteredData.map((row) => DataRow(
                  onSelectChanged: (_) => _showRecordDetails(row),
                  cells: row.values.map((val) => DataCell(
                    Text(val?.toString() ?? "---", style: const TextStyle(color: Colors.white70, fontSize: 13))
                  )).toList(),
                )).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 100, color: Colors.blue.withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text("مرحباً محمود علي عبيد", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("اختر جدوالاً من القائمة الجانبية لبدء الإدارة", style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 40),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMiniCard("قاعدة البيانات", "نشط", Colors.green),
              const SizedBox(width: 15),
              _buildMiniCard("الصلاحيات", "SERVICE ROLE", Colors.orange),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniCard(String title, String val, Color col) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Text(val, style: TextStyle(color: col, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  void _showRecordDetails(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("التفاصيل الكاملة للسجل", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white10, height: 30),
            Expanded(
              child: ListView(
                children: row.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key.toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SelectableText(e.value?.toString() ?? "لا توجد قيمة", style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
          const SizedBox(height: 15),
          Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => ref.read(databaseProvider.notifier).fetchTableData(_selectedTable!),
            child: const Text("إعادة المحاولة"),
          )
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback tap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white54, size: 20),
      onPressed: tap,
      constraints: const BoxConstraints(),
    );
  }
}
