import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:ui' as ui;
import '../../../../core/widgets/stat_card.dart';
import '../providers/stats_provider.dart';
import '../widgets/recent_invoice_tile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../services/backup_service.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged.map((list) => list.first);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isAdmin = auth.isAdmin;
    final isDelivery = auth.isDelivery;
    final stats = ref.watch(statsProvider);
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity == ConnectivityResult.none;

    return WillPopScope(
      onWillPop: () => _showExitDialog(context, ref, user),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 230.0,
                floating: true,
                pinned: true,
                backgroundColor: const Color(0xFF0D1B2A),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(right: 16, bottom: 16),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white24,
                        backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                        child: user?.avatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user?.fullName ?? 'مدير النظام',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20, top: 50),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$greeting،', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            Text(user?.fullName ?? 'محمود عبيد', 
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            _buildStatusBadge(isOffline),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () => context.push('/admin/notifications'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => _showExitDialog(context, ref, user),
                  ),
                ],
              ),
              if (isOffline)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.orange.shade900,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text('وضع العمل بدون اتصال نشط حالياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: stats.when(
                  data: (data) => _buildMainContent(context, data, isAdmin, isDelivery),
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())),
                  error: (e, _) => _buildErrorWidget(ref, e),
                ),
              ),
            ],
          ),
          drawer: _buildFullDrawer(context, ref, user, isAdmin, isDelivery),
        ),
      ),
    );
  }

  static Widget _buildStatusBadge(bool isOffline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOffline ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOffline ? Colors.orange : Colors.green),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: isOffline ? Colors.orange : Colors.green),
          const SizedBox(width: 8),
          Text(isOffline ? 'وضع الأوفلاين' : 'متصل بالسيرفر', 
              style: TextStyle(color: isOffline ? Colors.orange : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, Map<String, dynamic> s, bool isAdmin, bool isDelivery) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('نظرة عامة اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              StatCard(title: 'المبيعات', value: '${s['totalSales'] ?? 0} ريال', icon: Icons.monetization_on, color: Colors.green),
              StatCard(title: 'الطلبات', value: '${s['newOrders'] ?? 0}', icon: Icons.shopping_cart, color: Colors.blue),
              StatCard(title: 'الفواتير', value: '${s['dailyInvoices'] ?? 0}', icon: Icons.receipt, color: Colors.orange),
              StatCard(title: 'النواقص', value: '${s['lowStock'] ?? 0}', icon: Icons.warning, color: Colors.red),
            ],
          ),
          const SizedBox(height: 25),
          const Text('إجراءات سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _actionBtn(context, 'فاتورة', Icons.receipt_long, Colors.blue, () => context.push('/invoice')),
                _actionBtn(context, 'منتج', Icons.add_box_outlined, Colors.purple, () => context.push('/admin/manage-products')),
                _actionBtn(context, 'عميل', Icons.person_add_alt, Colors.teal, () => context.push('/admin/customers')),
                _actionBtn(context, 'تقرير', Icons.analytics_outlined, Colors.indigo, () => context.push('/admin/reports')),
              ],
            ),
          ),
          const SizedBox(height: 25),
          if ((s['lowStock'] ?? 0) > 0) _buildStockAlert(context, s['lowStock']),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('أحدث العمليات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => context.push('/admin/invoices'), child: const Text('عرض الكل')),
            ],
          ),
          ...List.generate(3, (index) => RecentInvoiceTile(
            number: 'INV-2026-${1050 - index}',
            customer: index == 0 ? 'مؤسسة الوفاء' : 'محلات المجد',
            amount: 1500.0 + (index * 200),
            date: DateTime.now(),
          )),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext ctx, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockAlert(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text('هناك $count أصناف شارفت على الانتهاء من المخزن!', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => context.push('/admin/low-stock'), 
            child: const Text('فحص'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullDrawer(BuildContext context, WidgetRef ref, user, bool isAdmin, bool isDelivery) {
    return Drawer(
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(user),
            _drawerTile(Icons.dashboard, 'لوحة التحكم', () => context.go('/home')),
            _drawerTile(Icons.inventory, 'المخازن والأصناف', () => context.push('/catalog')),
            _drawerTile(Icons.receipt_long, 'الفواتير والمبيعات', () => context.push('/admin/invoices')),
            if (isAdmin || isDelivery) ...[
              const Divider(),
              _buildExpandableSection('إدارة المخزون والمنتجات', [
                _drawerTile(Icons.edit_note, 'إدارة المنتجات', () => context.push('/admin/manage-products')),
                _drawerTile(Icons.import_export, 'استيراد من Excel', () => context.push('/import')),
                _drawerTile(Icons.file_download, 'تصدير المنتجات', () => context.push('/admin/export')),
              ]),
              _buildExpandableSection('العملاء والمبيعات', [
                _drawerTile(Icons.people, 'قائمة العملاء', () => context.push('/admin/customers')),
                _drawerTile(Icons.shopping_bag, 'الطلبات', () => context.push('/admin/orders')),
                _drawerTile(Icons.receipt_long, 'قائمة الفواتير', () => context.push('/admin/invoices')),
              ]),
            ],
            if (isAdmin) ...[
              const Divider(),
              _buildExpandableSection('لوحة تحكم المدير', [
                _drawerTile(Icons.admin_panel_settings, 'لوحة المدير', () => context.go('/admin')),
                _drawerTile(Icons.storage, 'قاعدة البيانات', () => context.push('/admin/database')),
                _drawerTile(Icons.notifications, 'إدارة الإشعارات', () => context.push('/admin/notifications')),
              ]),
              _buildExpandableSection('التقارير والتحليلات', [
                _drawerTile(Icons.analytics, 'التقارير', () => context.push('/admin/reports')),
                _drawerTile(Icons.trending_up, 'تحليلات متقدمة', () => context.push('/admin/advanced-analytics')),
              ]),
              _buildExpandableSection('الإعدادات المتقدمة', [
                _drawerTile(Icons.security, 'الصلاحيات والأدوار', () => context.push('/admin/roles-permissions')),
                _drawerTile(Icons.tune, 'تفضيلات النظام', () => context.push('/admin/system-preferences')),
                _drawerTile(Icons.link, 'إعدادات الاتصال', () => context.push('/admin/connection-settings')),
              ]),
              _buildExpandableSection('النظام والصيانة', [
                _drawerTile(Icons.backup, 'النسخ الاحتياطي', () => context.push('/admin/backup')),
                _drawerTile(Icons.history, 'سجل النشاطات', () => context.push('/admin/activity-log')),
              ]),
            ],
            if (isDelivery) ...[
              const Divider(),
              _drawerTile(Icons.delivery_dining, 'طلبات التوصيل', () => context.go('/delivery')),
            ],
            const Divider(),
            _drawerSectionTitle('الحساب'),
            _drawerTile(Icons.person, 'الملف الشخصي', () => context.push('/profile')),
            _drawerTile(Icons.settings, 'الإعدادات', () => context.push('/settings')),
            _drawerTile(Icons.security, 'مركز الصلاحيات', () => context.push('/permissions')),
            _drawerTile(Icons.exit_to_app, 'تسجيل الخروج', () => _showExitDialog(context, ref, user), color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, List<Widget> items) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      children: items,
    );
  }

  Widget _buildDrawerHeader(user) {
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color(0xFF0D1B2A)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.white12, child: Icon(Icons.business, color: Colors.white, size: 35)),
          const SizedBox(height: 12),
          Text(user?.fullName ?? 'محلات بن عبيد', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(user?.phone ?? 'الجمهورية اليمنية - إب', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF1B263B)),
      title: Text(title, style: TextStyle(color: color ?? const Color(0xFF1B263B), fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'طاب مساؤك';
  }

  static Future<bool> _showExitDialog(BuildContext context, WidgetRef ref, user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في إغلاق النظام؟ سيتم عمل نسخة احتياطية تلقائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (result == true) {
      await BackupService.createBackup(userRole: user?.role ?? 'admin');
      ref.read(authProvider.notifier).logout();
      context.go('/login');
    }
    return result ?? false;
  }

  Widget _buildErrorWidget(WidgetRef ref, Object e) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          Text('خطأ في تحميل البيانات: $e'),
          ElevatedButton(onPressed: () => ref.refresh(statsProvider), child: const Text('تحديث')),
        ],
      ),
    );
  }
}
