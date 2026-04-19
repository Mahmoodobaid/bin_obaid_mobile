import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final isOffline = auth.isOfflineMode;

    return WillPopScope(
      onWillPop: () => _showExitDialog(context, ref, user),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: true,
                pinned: true,
                snap: false,
                backgroundColor: Theme.of(context).primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(right: 16, bottom: 16),
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                        child: user?.avatarUrl == null ? const Icon(Icons.person, size: 18) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user?.fullName ?? 'مستخدم',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                        onPressed: () => context.push('/admin/notifications'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () => context.push('/catalog'),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          const Color(0xFF0D1B2A),
                          const Color(0xFF1B263B).withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, top: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting، ${user?.fullName ?? ''}',
                              style: const TextStyle(color: Colors.white70, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat.yMMMMEEEEd('ar').format(now),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.access_time, color: Colors.white54, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat.jm('ar').format(now),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOffline ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOffline ? Icons.wifi_off : Icons.wifi,
                                    color: isOffline ? Colors.orange : Colors.green,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOffline ? 'غير متصل' : 'متصل',
                                    style: TextStyle(
                                      color: isOffline ? Colors.orange : Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      isOffline ? Icons.sync_disabled : Icons.sync,
                      color: Colors.white,
                    ),
                    onPressed: isOffline ? null : () => ref.refresh(statsProvider),
                    tooltip: isOffline ? 'المزامنة غير متاحة' : 'مزامنة الآن',
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.white),
                    onPressed: () => _showExitDialog(context, ref, user),
                  ),
                ],
              ),
              if (isOffline)
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.orange.shade800,
                    child: const Text(
                      '⚠️ أنت في وضع الأوفلاين - البيانات المعروضة من التخزين المحلي',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: stats.when(
                  data: (s) => _buildContent(context, s, isAdmin, isDelivery),
                  loading: () => const _ShimmerContent(),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('فشل تحميل البيانات: $e', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.refresh(statsProvider),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          drawer: _buildDrawer(context, ref, user, isAdmin, isDelivery),
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

  String _getGreeting(int hour) {
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'مساء الخير';
  }

  Widget _buildContent(BuildContext ctx, Map<String, dynamic> s, bool isAdmin, bool isDelivery) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            children: [
              StatCard(title: 'طلبات جديدة', value: s['newOrders'].toString(), icon: Icons.shopping_bag, color: Colors.blue),
              StatCard(title: 'مبيعات', value: '${s['totalSales'].toStringAsFixed(2)} ريال', icon: Icons.attach_money, color: Colors.green),
              StatCard(title: 'فواتير يومية', value: s['dailyInvoices'].toString(), icon: Icons.receipt, color: Colors.orange),
              StatCard(title: 'أصناف متوفرة', value: s['availableProducts'].toString(), icon: Icons.inventory_2, color: Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          if (isAdmin || isDelivery)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الوصول السريع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _quickActionButton(ctx, Icons.receipt_long, 'فاتورة', () => ctx.push('/invoice')),
                      const SizedBox(width: 12),
                      _quickActionButton(ctx, Icons.add_shopping_cart, 'منتج', () => ctx.push('/admin/manage-products')),
                      const SizedBox(width: 12),
                      _quickActionButton(ctx, Icons.people, 'عميل', () => ctx.push('/admin/customers')),
                      const SizedBox(width: 12),
                      _quickActionButton(ctx, Icons.bar_chart, 'تقرير', () => ctx.push('/admin/reports')),
                      const SizedBox(width: 12),
                      if (isAdmin) _quickActionButton(ctx, Icons.backup, 'نسخ', () => ctx.push('/admin/backup')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),

          if (isAdmin || isDelivery) ...[
            const Text('تنبيهات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('منتجات قاربت على النفاد', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${s['lowStock'] ?? 0} منتجات تحتاج إعادة طلب', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => ctx.push('/admin/low-stock'), child: const Text('عرض')),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text('أحدث الفواتير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...List.generate(3, (i) => RecentInvoiceTile(
            number: 'INV-${1000 + i}',
            customer: 'عميل ${i + 1}',
            amount: 500.0 + i * 100,
            date: DateTime.now().subtract(Duration(days: i)),
          )),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => ctx.push('/admin/invoices'),
              child: const Text('عرض جميع الفواتير'),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () => ctx.push('/invoice'),
            icon: const Icon(Icons.add),
            label: const Text('فاتورة جديدة'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _quickActionButton(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(ctx).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Theme.of(ctx).primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(ctx).primaryColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Theme.of(ctx).primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx, WidgetRef ref, user, bool isAdmin, bool isDelivery) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
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
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext ctx, user) => DrawerHeader(
    decoration: const BoxDecoration(color: Color(0xFF0D1B2A)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
          child: user?.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        const SizedBox(height: 12),
        Text(user?.fullName ?? 'مستخدم', style: const TextStyle(color: Colors.white, fontSize: 18)),
        Row(
          children: [
            Text(user?.phone ?? '', style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.security, color: Colors.white70),
              onPressed: () => ctx.push('/permissions'),
              tooltip: 'إدارة الصلاحيات',
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildSection(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
      ),
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

class _ShimmerContent extends StatelessWidget {
  const _ShimmerContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            children: List.generate(4, (_) => Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
              ),
            )),
          ),
          const SizedBox(height: 24),
          Container(height: 20, width: 150, color: Colors.grey.shade800),
          const SizedBox(height: 12),
          ...List.generate(3, (_) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(12),
            ),
          )),
        ],
      ),
    );
  }
}
