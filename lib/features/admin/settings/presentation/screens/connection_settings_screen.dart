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
  String _statusMessage = 'جاهز للفحص الشامل';
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
    _urlController.text = prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;
    _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
    _checkRole(_keyController.text);
    if (mounted) setState(() {});
  }

  void _checkRole(String key) {
    setState(() => _isServiceRole = key.contains("service_role"));
  }

  void _addLog(String msg, Color color) {
    if (mounted) {
      setState(() => _logs.insert(0, _LogEntry(msg, color, DateTime.now())));
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _logs = [];
      _statusMessage = 'جاري التشخيص...';
      _statusColor = Colors.blue;
    });

    try {
      // 1. Connectivity Check
      _addLog("📡 فحص اتصال الهاتف بالشبكة...", Colors.blue);
      var connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) throw "الهاتف غير متصل بالشبكة.";
      _addLog("✅ الهاتف متصل بالشبكة.", Colors.green);

      // 2. Internet Access
      _addLog("🌍 فحص الوصول للإنترنت العالمي...", Colors.blue);
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
        if (result.isEmpty) throw "لا يوجد إنترنت.";
        _addLog("✅ الإنترنت متاح.", Colors.green);
      } catch (_) { throw "الشبكة متصلة ولكن لا يوجد إنترنت فعلي."; }

      // 3. DNS Lookup
      String url = _urlController.text.trim();
      Uri uri = Uri.parse(url);
      _addLog("🔍 فحص DNS للسيرفر: ${uri.host}", Colors.blue);
      await InternetAddress.lookup(uri.host).timeout(const Duration(seconds: 5));
      _addLog("✅ تم العثور على عنوان السيرفر بنجاح.", Colors.green);

      // 4. API Request
      _addLog("🔑 اختبار مفتاح API والاتصال بالخادم...", Colors.blue);
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final response = await dio.get('$url/rest/v1/', options: Options(headers: {
        'apikey': _keyController.text.trim(),
        'Authorization': 'Bearer ${_keyController.text.trim()}',
      }));

      if (response.statusCode == 200) {
        _addLog("🚀 تم الاتصال بنجاح تام! السيرفر مستجيب.", Colors.green);
        setState(() {
          _statusMessage = "✅ النظام متصل وجاهز";
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      String errorMsg = e.toString();
      _addLog("❌ فشل: $errorMsg", Colors.red);
      _analyzeError(errorMsg);
      setState(() {
        _statusMessage = "❌ فشل الاتصال";
        _statusColor = Colors.red;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _analyzeError(String error) {
    if (error.contains("401")) _addLog("💡 نصيحة: المفتاح غير صحيح، تأكد من نسخه كاملاً.", Colors.orange);
    else if (error.contains("403")) _addLog("💡 نصيحة: تم رفض الوصول، راجع إعدادات RLS.", Colors.orange);
    else _addLog("💡 نصيحة: تأكد من الرابط أو جرب شبكة أخرى.", Colors.orange);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_supabase_url', _urlController.text.trim());
    await prefs.setString('custom_supabase_key', _keyController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح ✅')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مهندس الاتصال الذكي'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Theme.of(context).primaryColor.withOpacity(0.1), Colors.white],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInputCard(),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 20),
                _buildLogsPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'رابط الخادم (URL)', prefixIcon: Icon(Icons.link)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _keyController,
              maxLines: 2,
              onChanged: _checkRole,
              decoration: const InputDecoration(labelText: 'مفتاح الـ API', prefixIcon: Icon(Icons.vpn_key)),
            ),
            if (_isServiceRole)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("🛡️ مفتاح مدير النظام (Service Role) نشط", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _runDiagnostics,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.bolt),
            label: const Text('بدء التشخيص'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            icon: const Icon(Icons.save),
            label: const Text('حفظ البيانات'),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsPanel() {
    return Container(
      height: 300,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _statusColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: _statusColor),
              const SizedBox(width: 8),
              Text(_statusMessage, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(),
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text("اضغط 'بدء التشخيص' لفحص حالة النظام"))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      final log = _logs[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text("${log.time.hour}:${log.time.minute.toString().padLeft(2, '0')} - ${log.message}", 
                        style: TextStyle(color: log.color, fontSize: 13, fontFamily: 'monospace')),
                      );
                    },
                  ),
          ),
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
