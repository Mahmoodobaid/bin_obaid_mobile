import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

// -------------------------------------------------------------------------
// 1. الإعدادات السحابية (نظام بن عبيد - الوصول المطلق)
// -------------------------------------------------------------------------
class BinObaidConfig {
  static const String url = "https://ackxfnznrjufhppaznjd.supabase.co";
  // مفتاح Service Role لضمان الصلاحيات الكاملة وتجاوز الـ RLS
  static const String serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY";
}

// -------------------------------------------------------------------------
// 2. محرك إدارة الحالة والتقارير الذكية
// -------------------------------------------------------------------------
class DatabaseState {
  final List<String> tables;
  final List<Map<String, dynamic>> data;
  final bool isLoading;
  final String? detailedReport;

  DatabaseState({this.tables = const [], this.data = const [], this.isLoading = false, this.detailedReport});

  DatabaseState copyWith({List<String>? tables, List<Map<String, dynamic>>? data, bool? isLoading, String? detailedReport}) {
    return DatabaseState(
      tables: tables ?? this.tables,
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      detailedReport: detailedReport,
    );
  }
}

class DatabaseNotifier extends StateNotifier<DatabaseState> {
  DatabaseNotifier() : super(DatabaseState());

  final _adminClient = SupabaseClient(BinObaidConfig.url, BinObaidConfig.serviceKey);

  Future<void> initSystem() async {
    state = state.copyWith(isLoading: true);
    const activeTables = ['products', 'users', 'pending_users', 'quotes', 'quote_items', 'logs', 'settings', 'sync_queue'];
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(tables: activeTables, isLoading: false);
  }

  Future<void> syncTable(String tableName) async {
    state = state.copyWith(isLoading: true, data: [], detailedReport: null);
    try {
      final response = await _adminClient
          .from(tableName)
          .select()
          .order('created_at', ascending: false)
          .limit(500);
      
      state = state.copyWith(data: List<Map<String, dynamic>>.from(response), isLoading: false);
    } catch (e) {
      // تحليل الخطأ بناءً على تقرير التشخيص
      String report = "🛠 تشخيص العطل:\n";
      if (e.toString().contains("Failed host lookup")) {
        report += "• مشكلة في الـ DNS أو الإنترنت (تعذر الوصول للسيرفر).";
      } else if (e.toString().contains("401")) {
        report += "• خطأ في الصلاحيات (Key Unauthorized).";
      } else {
        report += "• خطأ تقني غير متوقع: ${e.toString()}";
      }
      state = state.copyWith(isLoading: false, detailedReport: report);
    }
  }
}

final databaseProvider = StateNotifierProvider<DatabaseNotifier, DatabaseState>((ref) => DatabaseNotifier());

// -------------------------------------------------------------------------
// 3. الواجهة الرسومية (Ultra Premium UI v2.2)
// -------------------------------------------------------------------------
class BinObaidPremiumScreen extends ConsumerStatefulWidget {
  const BinObaidPremiumScreen({super.key});

  @override
  ConsumerState<BinObaidPremiumScreen> createState() => _BinObaidPremiumScreenState();
}

class _BinObaidPremiumScreenState extends ConsumerState<BinObaidPremiumScreen> {
  String? _currentTable;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => ref.read(databaseProvider.notifier).initSystem());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(databaseProvider);
    final size = MediaQuery.of(context).size;

    final filteredData = state.data.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(_query.toLowerCase()));
    }).toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Dark Navy
        drawer: size.width <= 1000 ? Drawer(child: _buildSidebar(state, isDrawer: true)) : null,
        body: Row(
          children: [
            if (size.width > 1000) _buildSidebar(state),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _currentTable == null 
                        ? _buildWelcomeHero()
                        : _buildMainContent(filteredData, state),
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

  Widget _buildTopBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width <= 1000)
            IconButton(icon: const Icon(Icons.menu_open_rounded, color: Colors.blue), onPressed: () => Scaffold.of(context).openDrawer()),
          
          Text(_currentTable == null ? "لوحة الإدارة" : "إدارة ${_currentTable!.toUpperCase()}", 
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          
          const Spacer(),
          _buildSearchInput(),
          const SizedBox(width: 15),
          _buildActionBtn(Icons.refresh_rounded, () {
            if (_currentTable != null) ref.read(databaseProvider.notifier).syncTable(_currentTable!);
          }),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      width: 300,
      height: 45,
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'بحث سريع...',
          hintStyle: TextStyle(color: Colors.white24),
          prefixIcon: Icon(Icons.search, color: Colors.blue, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSidebar(DatabaseState state, {bool isDrawer = false}) {
    return Container(
      width: 280,
      color: const Color(0xFF0B1222),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const CircleAvatar(radius: 40, backgroundColor: Colors.blue, child: Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 45)),
          const SizedBox(height: 15),
          const Text('Bin Obaid Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          const Text('V2.2 PREMIUM', style: TextStyle(color: Colors.blue, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: state.tables.length,
              itemBuilder: (context, i) {
                final table = state.tables[i];
                final active = _currentTable == table;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentTable = table);
                    ref.read(databaseProvider.notifier).syncTable(table);
                    if (isDrawer) Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: active ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? Colors.blue.withOpacity(0.3) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.layers_outlined, color: active ? Colors.blue : Colors.white24),
                        const SizedBox(width: 15),
                        Text(table.toUpperCase(), style: TextStyle(color: active ? Colors.blue : Colors.white70, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> data, DatabaseState state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: Colors.blue));
    if (state.detailedReport != null) return _buildErrorReport(state.detailedReport!);
    if (data.isEmpty) return _buildEmpty();

    return Padding(
      padding: const EdgeInsets.all(25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: const Color(0xFF1E293B),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.blue.withOpacity(0.05)),
              columns: data.first.keys.map((k) => DataColumn(label: Text(k, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))).toList(),
              rows: data.map((row) => DataRow(
                cells: row.values.map((v) => DataCell(
                  Text(v?.toString() ?? "---", style: const TextStyle(color: Colors.white70))
                )).toList(),
                onSelectChanged: (_) => _showDetails(row),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHero() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt_rounded, size: 100, color: Colors.blue),
          const SizedBox(height: 20),
          const Text("مرحباً محمود علي عبيد 👋", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const Text("نظام الإدارة المتكامل لمؤسسة بن عبيد جاهز للعمل.", style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSimpleStat("الجداول", "8", Colors.blue),
              const SizedBox(width: 20),
              _buildSimpleStat("الحالة", "متصل", Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String t, String v, Color c) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Text(v, style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(t, style: const TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErrorReport(String report) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(25)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.report_gmailerrorred_rounded, color: Colors.red, size: 80),
            const SizedBox(height: 20),
            const Text("تعذر جلب البيانات من السحابة", style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Text(report, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.6)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => ref.read(databaseProvider.notifier).syncTable(_currentTable!),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
              child: const Text("إعادة المحاولة الآن"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(child: Text("لا توجد بيانات متاحة في هذا الجدول.", style: TextStyle(color: Colors.white38)));
  }

  void _showDetails(Map<String, dynamic> row) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("تفاصيل السجل", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView(
                children: row.entries.map((e) => ListTile(
                  title: Text(e.key.toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  subtitle: Text(e.value?.toString() ?? "N/A", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.blue, size: 22),
      ),
    );
  }
}
