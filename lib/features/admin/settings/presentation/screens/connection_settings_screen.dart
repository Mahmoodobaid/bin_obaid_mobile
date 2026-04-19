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
  String _statusMessage = 'نظام التشخيص جاهز';
  Color _statusColor = Colors.grey;
  List<_LogEntry> _logs = [];
  bool _isServiceRole = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;
      _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
      _checkKeyType(_keyController.text);
    });
  }

  void _checkKeyType(String val) => setState(() => _isServiceRole = val.contains("service_role"));

  void _addLog(String message, Color color) {
    if (mounted) {
      setState(() => _logs.insert(0, _LogEntry(message, color, DateTime.now())));
    }
  }

  Future<void> _runFullDiagnostics() async {
    setState(() {
      _isLoading = true;
      _logs = [];
      _statusMessage = 'جاري الفحص الشامل...';
      _statusColor = Colors.blue;
    });

    try {
      _addLog("📡 فحص الاتصال بالشبكة المحلية...", Colors.blue);
      var connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) throw "الجهاز غير متصل بأي شبكة!";
      _addLog("✅ متصل بالشبكة بنجاح.", Colors.green);

      _addLog("🌍 فحص الوصول للإنترنت العالمي...", Colors.blue);
      final dns = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      if (dns.isEmpty) throw "لا يوجد وصول للإنترنت.";
      _addLog("✅ الإنترنت متاح.", Colors.green);

      _addLog("🔍 فحص DNS للسيرفر الخاص بك...", Colors.blue);
      Uri uri = Uri.parse(_urlController.text.trim());
      await InternetAddress.lookup(uri.host).timeout(const Duration(seconds: 5));
      _addLog("✅ تم العثور على عنوان السيرفر.", Colors.green);

      _addLog("🔑 اختبار مفتاح API واستجابة الخادم...", Colors.blue);
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
      final response = await dio.get('${_urlController.text.trim()}/rest/v1/', options: Options(headers: {
        'apikey': _keyController.text.trim(),
        'Authorization': 'Bearer ${_keyController.text.trim()}',
      }));

      if (response.statusCode == 200) {
        _addLog("🚀 تم الاتصال بنجاح! السيرفر يستجيب بشكل مثالي.", Colors.green);
        setState(() {
          _statusMessage = "تم الاتصال بنجاح ✅";
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      _addLog("❌ فشل التشخيص: $e", Colors.red);
      setState(() {
        _statusMessage = "فشل في الاتصال ❌";
        _statusColor = Colors.red;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_supabase_url', _urlController.text.trim());
    await prefs.setString('custom_supabase_key', _keyController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح ✅')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مهندس الاتصال الذكي'), centerTitle: true, elevation: 0),
        body: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Theme.of(context).primaryColor.withOpacity(0.1), Colors.white])),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCard("إعدادات السيرفر", [
                  TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'رابط Supabase URL', prefixIcon: Icon(Icons.link))),
                  const SizedBox(height: 15),
                  TextField(controller: _keyController, maxLines: 2, onChanged: _checkKeyType, decoration: const InputDecoration(labelText: 'مفتاح الـ API', prefixIcon: Icon(Icons.vpn_key))),
                  if (_isServiceRole) const Padding(padding: EdgeInsets.only(top: 8), child: Text("🛡️ وضع مدير النظام (Service Role) نشط", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
                ]),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(onPressed: _isLoading ? null : _runFullDiagnostics, icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bolt), label: const Text('بدء التشخيص'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ البيانات'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)))),
                  ],
                ),
                const SizedBox(height: 25),
                _buildLogsPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const Divider(),
        ...children,
      ])),
    );
  }

  Widget _buildLogsPanel() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: _statusColor.withOpacity(0.5))),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(children: [Icon(Icons.terminal, color: _statusColor), const SizedBox(width: 8), Text(_statusMessage, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold))]),
          const Divider(),
          Expanded(child: _logs.isEmpty ? const Center(child: Text("بانتظار بدء الفحص...")) : ListView.builder(itemCount: _logs.length, itemBuilder: (context, i) {
            final log = _logs[i];
            return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text("${log.time.hour}:${log.time.minute.toString().padLeft(2, '0')} - ${log.message}", style: TextStyle(color: log.color, fontSize: 12, fontFamily: 'monospace')));
          })),
        ],
      ),
    );
  }
}

class _LogEntry {
  final String message;
  final Color color;
  final DateTime time;
  _LogEntry(this.message, this.color, this.time);
}
