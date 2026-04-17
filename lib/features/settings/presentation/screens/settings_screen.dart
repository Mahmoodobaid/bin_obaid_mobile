import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = true;
  bool _notificationsEnabled = true;
  String _language = 'ar';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? true;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _language = prefs.getString('language') ?? 'ar';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  Future<void> _syncData() async {
    setState(() => _isLoading = true);
    // محاكاة مزامنة
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تمت مزامنة البيانات بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_products');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم مسح البيانات المحلية'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('المظهر'),
            SwitchListTile(
              title: const Text('الوضع الليلي'),
              subtitle: const Text('تفعيل المظهر الداكن'),
              value: _darkMode,
              onChanged: (v) {
                setState(() => _darkMode = v);
                _saveSetting('darkMode', v);
              },
            ),
            const Divider(),
            _buildSectionTitle('الإشعارات'),
            SwitchListTile(
              title: const Text('تفعيل الإشعارات'),
              subtitle: const Text('استلام إشعارات الطلبات الجديدة'),
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                _saveSetting('notifications', v);
              },
            ),
            const Divider(),
            _buildSectionTitle('اللغة'),
            RadioListTile<String>(
              title: const Text('العربية'),
              value: 'ar',
              groupValue: _language,
              onChanged: (v) {
                setState(() => _language = v!);
                _saveSetting('language', v);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _language,
              onChanged: (v) {
                setState(() => _language = v!);
                _saveSetting('language', v);
              },
            ),
            const Divider(),
            _buildSectionTitle('البيانات والمزامنة'),
            ListTile(
              leading: const Icon(Icons.sync, color: Color(0xFF0F3BBF)),
              title: const Text('مزامنة البيانات الآن'),
              subtitle: const Text('تحديث البيانات من الخادم'),
              trailing: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _isLoading ? null : _syncData,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('مسح البيانات المحلية'),
              subtitle: const Text('حذف المنتجات المخزنة مؤقتاً'),
              onTap: _clearCache,
            ),
            const Divider(),
            _buildSectionTitle('عن التطبيق'),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('إصدار التطبيق'),
              subtitle: const Text('2.0.0'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('سياسة الخصوصية'),
              onTap: () {
                // يمكن فتح صفحة ويب
              },
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('الشروط والأحكام'),
              onTap: () {
                // يمكن فتح صفحة ويب
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFDCC86E),
        ),
      ),
    );
  }
}
