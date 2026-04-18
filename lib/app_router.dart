import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/admin/presentation/screens/admin_screen.dart';
import 'features/admin/presentation/screens/database_manager_screen.dart';
import 'features/delivery/presentation/screens/delivery_screen.dart';
import 'features/catalog/presentation/screens/product_list_screen.dart';
import 'features/catalog/presentation/screens/product_detail_screen.dart';
import 'features/cart/presentation/screens/cart_screen.dart';
import 'features/invoices/presentation/screens/invoice_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/admin/import_export/presentation/screens/import_products_screen.dart';
import 'features/admin/manage_products/presentation/screens/manage_products_screen.dart';
import 'features/admin/export/presentation/screens/export_products_screen.dart';
import 'features/admin/connection_settings/presentation/screens/connection_settings_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    initialLocation: '/login',
    redirect: (ctx, state) {
      final logged = auth.isAuthenticated;
      final toLogin = state.matchedLocation == '/login';
      final toReg = state.matchedLocation == '/register';
      if (toReg) return null;
      if (!logged && !toLogin) return '/login';
      if (logged && toLogin) return '/home';
      if (state.matchedLocation.startsWith('/admin') && !auth.isAdmin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/catalog', builder: (_, __) => const ProductListScreen()),
      GoRoute(path: '/product/:sku', builder: (_, state) => ProductDetailScreen(sku: state.pathParameters['sku']!)),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/invoice', builder: (_, __) => const InvoiceScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen(), routes: [
        GoRoute(path: 'database', builder: (_, __) => const DatabaseManagerScreen()),
        GoRoute(path: 'manage-products', builder: (_, __) => const ManageProductsScreen()),
        GoRoute(path: 'export', builder: (_, __) => const ExportProductsScreen()),
        GoRoute(path: 'connection-settings', builder: (_, __) => const ConnectionSettingsScreen()),
      ]),
      GoRoute(path: '/import', builder: (_, __) => const ImportProductsScreen()),
      GoRoute(path: '/delivery', builder: (_, __) => const DeliveryScreen()),
    ],
  );
});

// المسارات الجديدة (تضاف تلقائياً)
GoRoute(path: '/admin/customers', builder: (_, __) => const CustomersScreen()),
GoRoute(path: '/admin/orders', builder: (_, __) => const OrdersScreen()),
GoRoute(path: '/admin/invoices', builder: (_, __) => const InvoicesListScreen()),
GoRoute(path: '/admin/notifications', builder: (_, __) => const NotificationManagerScreen()),
GoRoute(path: '/admin/announcements', builder: (_, __) => const AnnouncementsScreen()),
GoRoute(path: '/admin/reports', builder: (_, __) => const ReportsScreen()),
GoRoute(path: '/admin/advanced-analytics', builder: (_, __) => const AdvancedAnalyticsScreen()),
GoRoute(path: '/admin/roles-permissions', builder: (_, __) => const RolesPermissionsScreen()),
GoRoute(path: '/admin/system-preferences', builder: (_, __) => const SystemPreferencesScreen()),
GoRoute(path: '/admin/backup', builder: (_, __) => const BackupScreen()),
GoRoute(path: '/admin/activity-log', builder: (_, __) => const ActivityLogScreen()),
