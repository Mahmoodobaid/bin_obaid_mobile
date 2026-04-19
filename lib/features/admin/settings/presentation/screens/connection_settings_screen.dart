import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  String _connectionStatus = 'جاهز للفحص الشامل';
  Color _statusColor = Colors.grey;
  List<String> _diagnosticsLogs = [];
  bool _isServiceRole = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;
      _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
      _isServiceRole = _keyController.text.contains("service_role");
    });
  }

  void _updateLogs(String message) {
    if (mounted) {
      setState(() {
        final timestamp = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
        _diagnosticsLogs.insert(0, "$timestamp - $message");
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _diagnosticsLogs = [];
      _connectionStatus = 'جاري الفحص...';
      _statusColor = Colors.blue;
    });

    try {
      _updateLogs("📡 فحص الاتصال بالإنترنت...");
      var connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) throw "لا يوجد اتصال بالشبكة.";

      _updateLogs("🌍 فحص الوصول لسيرفرات جوجل (DNS)...");
      final dnsTest = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      if (dnsTest.isEmpty) throw "الشبكة متصلة ولكن لا يوجد إنترنت.";

      _updateLogs("🔑 فحص استجابة سيرفر Supabase...");
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
      final response = await dio.get('${_urlController.text.trim()}/rest/v1/', options: Options(headers: {
        'apikey': _keyController.text.trim(),
        'Authorization': 'Bearer ${_keyController.text.trim()}',
      }));

      if (response.statusCode == 200) {
        _updateLogs("✅ تم الاتصال بنجاح! السيرفر يعمل.");
        setState(() {
          _connectionStatus = "متصل بنجاح ✅";
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      _updateLogs("❌ خطأ: $e");
      setState(() {
        _connectionStatus = "فشل الاتصال ❌";
        _statusColor = Colors.red;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_supabase_url', _urlController.text.trim());
    await prefs.setString('custom_supabase_key', _keyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات بنجاح ✅')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مهندس الاتصال الاحترافي'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCard(
                  "بيانات السيرفر",
                  [
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'رابط Supabase URL',
                        prefixIcon: Icon(Icons.cloud_queue),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _keyController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'مفتاح API (Anon Key)',
                        prefixIcon: Icon(Icons.security),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_isServiceRole)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("⚠️ تنبيه: أنت تستخدم مفتاح مدير النظام", 
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testConnection,
                        icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.network_check),
                        label: const Text('اختبار الاتصال'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ البيانات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                _buildDiagnosticsPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const Divider(),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsPanel() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _statusColor.withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("تقرير التشخيص", style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor)),
              Icon(Icons.monitor_heart, color: _statusColor),
            ],
          ),
          const Divider(),
          Center(child: Text(_connectionStatus, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _statusColor))),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _diagnosticsLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_diagnosticsLogs[index], style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'monospace')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
