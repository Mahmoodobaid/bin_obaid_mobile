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
  String _connectionStatus = 'نظام التشخيص جاهز';
  Color _statusColor = Colors.grey;
  List<String> _diagnosticsLogs = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;
      _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
    });
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        final time = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
        _diagnosticsLogs.insert(0, "$time - $message");
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
      _addLog("📡 فحص اتصال الشبكة...");
      var connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) throw "لا يوجد اتصال بالإنترنت.";

      _addLog("🌍 اختبار الوصول للسيرفر...");
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
      final response = await dio.get('${_urlController.text.trim()}/rest/v1/', options: Options(headers: {
        'apikey': _keyController.text.trim(),
        'Authorization': 'Bearer ${_keyController.text.trim()}',
      }));

      if (response.statusCode == 200) {
        _addLog("✅ تم الاتصال بنجاح!");
        setState(() {
          _connectionStatus = "متصل بنجاح ✅";
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      _addLog("❌ فشل: $e");
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح ✅')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الاتصال الاحترافية'),
          flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]))),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'Supabase URL', prefixIcon: Icon(Icons.link))),
                      const SizedBox(height: 15),
                      TextField(controller: _keyController, maxLines: 2, decoration: const InputDecoration(labelText: 'API Key', prefixIcon: Icon(Icons.vpn_key))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: ElevatedButton.icon(onPressed: _isLoading ? null : _testConnection, icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bolt), label: const Text('بدء الفحص'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(onPressed: _saveSettings, icon: const Icon(Icons.save), label: const Text('حفظ الإعدادات'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)))),
                ],
              ),
              const SizedBox(height: 25),
              _buildLogsPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogsPanel() {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _statusColor, width: 2)),
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Text(_connectionStatus, style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor, fontSize: 16)),
          const Divider(),
          Expanded(child: ListView.builder(itemCount: _diagnosticsLogs.length, itemBuilder: (context, i) => Text(_diagnosticsLogs[i], style: const TextStyle(fontSize: 12, fontFamily: 'monospace')))),
        ],
      ),
    );
  }
}
