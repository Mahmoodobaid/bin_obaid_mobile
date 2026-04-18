import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildReportTile('تقرير المبيعات الشهري', Icons.bar_chart, () {}),
            _buildReportTile('تقرير المخزون', Icons.inventory, () {}),
            _buildReportTile('تقرير العملاء', Icons.people, () {}),
            _buildReportTile('تقرير الفواتير', Icons.receipt, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTile(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}
