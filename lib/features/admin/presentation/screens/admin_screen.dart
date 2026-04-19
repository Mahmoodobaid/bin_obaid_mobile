import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_request_provider.dart';
import '../../../../models/user_model.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(adminRequestProvider.notifier).loadRequests());
  }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminRequestProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
          title: const Text('لوحة تحكم المدير'),
          bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'طلبات التسجيل'), Tab(text: 'استعادة كلمة المرور')]),
        ),
        body: TabBarView(controller: _tab, children: [
          _buildPendingUsersList(state.pendingUsers),
          _buildPasswordResetList(state.passwordResetRequests),
        ]),
      ),
    );
  }

  Widget _buildPendingUsersList(List<PendingUser> users) {
    if (users.isEmpty) return const Center(child: Text('لا توجد طلبات معلقة'));
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (c, i) {
        final u = users[i];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: u.imageUrl != null ? Image.network(u.imageUrl!, width: 50, fit: BoxFit.cover) : null,
            title: Text(u.fullName),
            subtitle: Text('${u.phone}\n${u.occupation}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _approve(u, 'customer')),
                IconButton(icon: const Icon(Icons.admin_panel_settings, color: Colors.blue), onPressed: () => _approve(u, 'delivery')),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _reject(u)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordResetList(List<PasswordResetRequest> requests) {
    if (requests.isEmpty) return const Center(child: Text('لا توجد طلبات استعادة'));
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (c, i) {
        final r = requests[i];
        return ListTile(title: Text(r.phone), trailing: ElevatedButton(onPressed: () {}, child: const Text('إرسال')));
      },
    );
  }

  void _approve(PendingUser u, String role) {
    ref.read(adminRequestProvider.notifier).approveUser(u.id, u.phone, u.fullName, role);
  }

  void _reject(PendingUser u) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) ref.read(adminRequestProvider.notifier).rejectUser(u.id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }
}
