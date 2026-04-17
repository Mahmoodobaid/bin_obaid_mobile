import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/stat_card.dart';
import '../providers/stats_provider.dart';
import '../widgets/recent_invoice_tile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isAdmin = auth.isAdmin;
    final isDelivery = auth.isDelivery;
    final stats = ref.watch(statsProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الرئيسية'), centerTitle: true),
        drawer: _buildDrawer(context, ref, user, isAdmin, isDelivery),
        body: stats.when(data: (s) => _buildContent(context, s), loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('$e'))),
      ),
    );
  }

  Widget _buildContent(BuildContext ctx, Map<String, dynamic> s) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.6, children: [
        StatCard(title: 'طلبات جديدة', value: s['newOrders'].toString(), icon: Icons.shopping_bag, color: Colors.blue),
        StatCard(title: 'مبيعات', value: '${s['totalSales'].toStringAsFixed(2)} ريال', icon: Icons.attach_money, color: Colors.green),
        StatCard(title: 'فواتير يومية', value: s['dailyInvoices'].toString(), icon: Icons.receipt, color: Colors.orange),
        StatCard(title: 'أصناف متوفرة', value: s['availableProducts'].toString(), icon: Icons.inventory_2, color: Colors.purple),
      ]),
      const SizedBox(height: 24),
      const Text('أحدث الفواتير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ...List.generate(3, (i) => RecentInvoiceTile(number: 'INV-${1000 + i}', customer: 'عميل ${i + 1}', amount: 500.0 + i * 100, date: DateTime.now().subtract(Duration(days: i)))),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: () => ctx.push('/invoice'), icon: const Icon(Icons.add), label: const Text('فاتورة جديدة'), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))),
    ]),
  );

  Widget _buildDrawer(BuildContext ctx, WidgetRef ref, user, bool isAdmin, bool isDelivery) => Drawer(
    child: ListView(padding: EdgeInsets.zero, children: [
      DrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF0D1B2A)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          CircleAvatar(radius: 30, backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null, child: user?.avatarUrl == null ? const Icon(Icons.person) : null),
          const SizedBox(height: 12),
          Text(user?.fullName ?? 'مستخدم', style: const TextStyle(color: Colors.white, fontSize: 18)),
          Text(user?.phone ?? '', style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      _item(Icons.dashboard, 'الرئيسية', () => ctx.go('/home')),
      _item(Icons.inventory_2, 'كتالوج المنتجات', () => ctx.go('/catalog')),
      _item(Icons.shopping_cart, 'سلة المشتريات', () => ctx.push('/cart')),
      _item(Icons.receipt, 'فاتورة جديدة', () => ctx.push('/invoice')),
      const Divider(),
      if (isAdmin) ...[
        _item(Icons.admin_panel_settings, 'لوحة المدير', () => ctx.go('/admin')),
        _item(Icons.storage, 'قاعدة البيانات', () => ctx.push('/admin/database')),
        _item(Icons.upload_file, 'استيراد Excel', () => ctx.push('/import')),
        const Divider(),
      ],
      if (isDelivery) _item(Icons.delivery_dining, 'طلبات التوصيل', () => ctx.go('/delivery')),
      _item(Icons.person, 'الملف الشخصي', () => ctx.push('/profile')),
      _item(Icons.settings, 'الإعدادات', () => ctx.push('/settings')),
      _item(Icons.logout, 'تسجيل الخروج', () { ref.read(authProvider.notifier).logout(); ctx.go('/login'); }, color: Colors.red),
    ]),
  );

  Widget _item(IconData icon, String title, VoidCallback onTap, {Color? color}) => ListTile(leading: Icon(icon, color: color ?? const Color(0xFF0F3BBF)), title: Text(title), onTap: onTap);
}
