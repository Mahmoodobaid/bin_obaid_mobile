import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../services/api_service.dart';
import '../../../../../models/user_model.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<UserModel> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    final api = ref.read(apiServiceProvider);
    try {
      // استخدام دالة مخصصة بدلاً من الوصول المباشر لـ _dio
      final data = await api.getTableData('users');
      setState(() {
        _customers = data
            .where((u) => u['role'] == 'customer')
            .map((u) => UserModel.fromJson(u))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل العملاء: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قائمة العملاء'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchCustomers,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _customers.isEmpty
                ? const Center(child: Text('لا يوجد عملاء مسجلين'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _customers.length,
                    itemBuilder: (_, i) {
                      final c = _customers[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(c.fullName.isNotEmpty ? c.fullName[0] : '؟'),
                          ),
                          title: Text(c.fullName),
                          subtitle: Text('${c.phone} • ${c.email}'),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
