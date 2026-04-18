import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../../../core/config/config.dart';

class ConnectionSettingsScreen extends ConsumerStatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  ConsumerState<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends ConsumerState<ConnectionSettingsScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String _connectionStatus = 'لم يتم الاختبار';
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _urlController.text = prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;
    _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
    setState(() {});
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_supabase_url', _urlController.text.trim());
    await prefs.setString('custom_supabase_key', _keyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حفظ الإعدادات. أعد تشغيل التطبيق لتفعيلها.')));
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'جاري الاختبار...';
      _statusColor = Colors.orange;
    });
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));
      final response = await dio.get(
        '${_urlController.text.trim()}/rest/v1/products?select=count',
        options: Options(headers: {'apikey': _keyController.text.trim(), 'Authorization': 'Bearer ${_keyController.text.trim()}'}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _connectionStatus = '✅ متصل - عدد المنتجات: ${response.data[0]['count']}';
          _statusColor = Colors.green;
        });
      } else {
        setState(() {
          _connectionStatus = '❌ فشل الاتصال - كود: ${response.statusCode}';
          _statusColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ فشل الاتصال: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إعدادات الاتصال بقاعدة البيانات')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('رابط Supabase', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _urlController, decoration: const InputDecoration(hintText: 'https://xxxx.supabase.co')),
                const SizedBox(height: 16),
                const Text('مفتاح API (Anon / Publishable)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _keyController, maxLines: 3, decoration: const InputDecoration(hintText: 'sb_publishable_... أو eyJhbGciOiJIUzI1NiIs...')),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(onPressed: _testConnection, icon: const Icon(Icons.wifi), label: const Text('اختبار الاتصال'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(onPressed: _saveSettings, icon: const Icon(Icons.save), label: const Text('حفظ الإعدادات'))),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _statusColor)),
                  child: Row(children: [
                    if (_isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.info_outline, color: _statusColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_connectionStatus, style: TextStyle(color: _statusColor))),
                  ]),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const Text('ملاحظة: بعد تغيير الإعدادات، يجب إعادة تشغيل التطبيق لتصبح سارية المفعول.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
