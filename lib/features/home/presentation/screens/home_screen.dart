import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/stat_card.dart';
import '../providers/stats_provider.dart';
import '../widgets/recent_invoice_tile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../services/backup_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isAdmin = auth.isAdmin;
    final isDelivery = auth.isDelivery;
    final stats = ref.watch(statsProvider);

    return WillPopScope(
      onWillPop: () => _showExitDialog(context, ref, user),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('الرئيسية'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => _showExitDialog(context, ref, user),
                tooltip: 'خروج',
              ),
            ],
          ),
          drawer: _buildDrawer(context, ref, user, isAdmin, isDelivery),
          body: stats.when(
            data: (s) => _buildContent(context, s),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          ),
        ),
      ),
    );
  }

  static Future<bool> _showExitDialog(BuildContext context, WidgetRef ref, user) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل تريد الخروج من نظام محلات بن عبيد التجارية؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم')),
        ],
      ),
    );

    if (shouldExit == true) {
      final userName = user?.fullName ?? 'المستخدم';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('شكراً لك $userName لاستخدام نظام محلات بن عبيد التجارية. وداعاً!'),
          duration: const Duration(seconds: 3),
        ),
      );
      final role = user?.role ?? 'customer';
      await BackupService.createBackup(userRole: role);
      ref.read(authProvider.notifier).logout();
      context.go('/login');
      return true;
    }
    return false;
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
      _buildDrawerHeader(ctx, user),
      _buildSection('الرئيسية', [
        _drawerItem(Icons.dashboard, 'الرئيسية', () => ctx.go('/home')),
        _drawerItem(Icons.inventory_2, 'كتالوج المنتجات', () => ctx.go('/catalog')),
        _drawerItem(Icons.shopping_cart, 'سلة المشتريات', () => ctx.push('/cart')),
        _drawerItem(Icons.receipt, 'فاتورة جديدة', () => ctx.push('/invoice')),
      ]),
      const Divider(),
      if (isAdmin || isDelivery) ...[
        _buildExpandableSection('إدارة المخزون والمنتجات', [
          _drawerItem(Icons.edit_note, 'إدارة المنتجات', () => ctx.push('/admin/manage-products')),
          _drawerItem(Icons.import_export, 'استيراد من Excel', () => ctx.push('/import')),
          _drawerItem(Icons.file_download, 'تصدير المنتجات', () => ctx.push('/admin/export')),
        ]),
        _buildExpandableSection('العملاء والمبيعات', [
          _drawerItem(Icons.people, 'قائمة العملاء', () => ctx.push('/admin/customers')),
          _drawerItem(Icons.shopping_bag, 'الطلبات', () => ctx.push('/admin/orders')),
          _drawerItem(Icons.receipt_long, 'قائمة الفواتير', () => ctx.push('/admin/invoices')),
        ]),
      ],
      if (isAdmin) ...[
        _buildExpandableSection('لوحة تحكم المدير', [
          _drawerItem(Icons.admin_panel_settings, 'لوحة المدير', () => ctx.go('/admin')),
          _drawerItem(Icons.storage, 'قاعدة البيانات', () => ctx.push('/admin/database')),
          _drawerItem(Icons.notifications, 'إدارة الإشعارات', () => ctx.push('/admin/notifications')),
        ]),
        _buildExpandableSection('التقارير والتحليلات', [
          _drawerItem(Icons.analytics, 'التقارير', () => ctx.push('/admin/reports')),
          _drawerItem(Icons.trending_up, 'تحليلات متقدمة', () => ctx.push('/admin/advanced-analytics')),
        ]),
        _buildExpandableSection('الإعدادات المتقدمة', [
          _drawerItem(Icons.security, 'الصلاحيات والأدوار', () => ctx.push('/admin/roles-permissions')),
          _drawerItem(Icons.tune, 'تفضيلات النظام', () => ctx.push('/admin/system-preferences')),
          _drawerItem(Icons.link, 'إعدادات الاتصال', () => ctx.push('/admin/connection-settings')),
        ]),
        _buildExpandableSection('النظام والصيانة', [
          _drawerItem(Icons.backup, 'النسخ الاحتياطي', () => ctx.push('/admin/backup')),
          _drawerItem(Icons.history, 'سجل النشاطات', () => ctx.push('/admin/activity-log')),
        ]),
      ],
      if (isDelivery) ...[
        _drawerItem(Icons.delivery_dining, 'طلبات التوصيل', () => ctx.go('/delivery')),
      ],
      const Divider(),
      _buildSection('الحساب', [
        _drawerItem(Icons.person, 'الملف الشخصي', () => ctx.push('/profile')),
        _drawerItem(Icons.settings, 'الإعدادات', () => ctx.push('/settings')),
        _drawerItem(Icons.logout, 'تسجيل الخروج', () => _showExitDialog(ctx, ref, user), color: Colors.red),
      ]),
      const SizedBox(height: 20),
    ]),
  );

  Widget _buildDrawerHeader(BuildContext ctx, user) => DrawerHeader(
    decoration: const BoxDecoration(color: Color(0xFF0D1B2A)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
      CircleAvatar(radius: 30, backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null, child: user?.avatarUrl == null ? const Icon(Icons.person) : null),
      const SizedBox(height: 12),
      Text(user?.fullName ?? 'مستخدم', style: const TextStyle(color: Colors.white, fontSize: 18)),
      Row(children: [
        Text(user?.phone ?? '', style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.security, color: Colors.white70), onPressed: () => ctx.push('/permissions'), tooltip: 'إدارة الصلاحيات'),
      ]),
    ]),
  );

  Widget _buildSection(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey))),
      ...items,
    ],
  );

  Widget _buildExpandableSection(String title, List<Widget> items) => ExpansionTile(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    children: items,
  );

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) => ListTile(
    leading: Icon(icon, color: color ?? const Color(0xFF0F3BBF)),
    title: Text(title),
    onTap: onTap,
    dense: true,
  );
}
