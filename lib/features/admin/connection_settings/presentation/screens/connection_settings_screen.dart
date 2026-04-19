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
  
  String _statusMessage = 'جاهز للفحص';
  Color _statusColor = Colors.grey;
  List<_DiagnosticEntry> _diagnostics = [];
  bool _isServiceRole = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // جلب الإعدادات المحفوظة أو استخدام الافتراضية من AppConfig
    _urlController.text = prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;
    _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
    _checkKeyType(_keyController.text);
    setState(() {});
  }

  void _checkKeyType(String key) {
    setState(() {
      // التحقق مما إذا كان المفتاح هو مفتاح الأدمن (Service Role)
      _isServiceRole = key.contains("service_role") || 
                       key.startsWith("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlI");
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _diagnostics = [];
      _statusMessage = 'بدء التشخيص الشامل...';
      _statusColor = Colors.blue;
    });

    try {
      // 1. فحص اتصال الهاتف بالشبكة المحلية
      _addLog("📡 فحص اتصال الهاتف...", Colors.blue);
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        throw "الهاتف غير متصل بالشبكة. يرجى تفعيل الواي فاي أو البيانات.";
      }
      _addLog("✅ الهاتف متصل بالشبكة", Colors.green);

      // 2. فحص الوصول الفعلي للإنترنت العالمي
      _addLog("🌍 فحص الوصول للإنترنت العالمي...", Colors.blue);
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
        if (result.isEmpty || result[0].rawAddress.isEmpty) throw "لا يوجد إنترنت";
        _addLog("✅ إنترنت عالمي متاح", Colors.green);
      } catch (_) {
        throw "الشبكة متصلة ولكن لا يوجد إنترنت فعلي (No Internet Access).";
      }

      // 3. تحليل الرابط و DNS الخاص بسيرفر Supabase
      String url = _urlController.text.trim();
      if (!url.startsWith("https://")) throw "الرابط يجب أن يبدأ بـ https://";
      
      Uri uri = Uri.parse(url);
      _addLog("🔍 فحص DNS لـ ${uri.host}...", Colors.blue);
      try {
        await InternetAddress.lookup(uri.host).timeout(const Duration(seconds: 5));
        _addLog("✅ DNS يعمل (تم العثور على السيرفر)", Colors.green);
      } catch (_) {
        throw "فشل في الوصول للسيرفر (DNS lookup failed). تأكد من صحة الرابط.";
      }

      // 4. اختبار الاتصال الفعلي بـ Supabase API وصلاحية المفتاح
      _addLog("🔑 اختبار الصلاحيات والاتصال بـ API...", Colors.blue);
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await dio.get(
        '$url/rest/v1/', // طلب معلومات الـ Schema للتأكد من الصلاحية
        options: Options(headers: {
          'apikey': _keyController.text.trim(),
          'Authorization': 'Bearer ${_keyController.text.trim()}',
        }),
      );

      if (response.statusCode == 200) {
        _addLog("✅ تم الاتصال بنجاح. السيرفر مستجيب.", Colors.green);
        setState(() {
          _statusMessage = "✅ اتصال ناجح! السيرفر جاهز.";
          _statusColor = Colors.green;
        });
      } else {
        throw "استجابة غير متوقعة من السيرفر: ${response.statusCode}";
      }

    } catch (e) {
      _addLog("❌ فشل: $e", Colors.red);
      setState(() {
        _statusMessage = "❌ فشل الاتصال";
        _statusColor = Colors.red;
      });
      _analyzeError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addLog(String message, Color color) {
    if (mounted) {
      setState(() {
        _diagnostics.add(_DiagnosticEntry(
          time: TimeOfDay.now(),
          message: message,
          color: color,
        ));
      });
    }
  }

  void _analyzeError(String error) {
    String hint = "تأكد من الرابط والمفتاح.";
    if (error.contains("401")) hint = "المفتاح غير صالح (Unauthorized).";
    if (error.contains("403")) hint = "تم رفض الوصول (Forbidden). تأكد من إعدادات RLS.";
    if (error.contains("timeout")) hint = "انتهت مهلة الاتصال. الشبكة بطيئة جداً.";
    _addLog("💡 نصيحة: $hint", Colors.orange);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_supabase_url', _urlController.text.trim());
    await prefs.setString('custom_supabase_key', _keyController.text.trim());
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تم الحفظ'),
        content: const Text('تم تحديث إعدادات الاتصال بنجاح.\n\nيُرجى إعادة تشغيل التطبيق لتفعيل التغييرات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مهندس الاتصال الذكي'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCurrentSettings),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.05),
                isDark ? Colors.black : Colors.white,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // بطاقة الإعدادات
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.settings_remote, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('إعدادات الخادم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'رابط Supabase URL',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _keyController,
                            maxLines: 3,
                            onChanged: _checkKeyType,
                            decoration: InputDecoration(
                              labelText: 'مفتاح API',
                              prefixIcon: const Icon(Icons.vpn_key),
                              suffixIcon: _isServiceRole 
                                ? const Tooltip(message: 'مفتاح مدير (Service Role)', child: Icon(Icons.verified_user, color: Colors.orange))
                                : null,
                            ),
                          ),
                          if (_isServiceRole)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                '🛡️ وضع الصلاحيات الكاملة (Admin Mode) نشط.',
                                style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // أزرار التحكم
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testConnection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Icon(Icons.bolt),
                          label: const Text('تشخيص الاتصال'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ الإعدادات'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // لوحة التشخيص والتقارير
                  _buildDiagnosticsPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تقرير التشخيص:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _statusColor.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: _statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(_statusMessage, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _diagnostics.length,
                  itemBuilder: (context, index) {
                    final entry = _diagnostics[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        "${entry.time.hour}:${entry.time.minute.toString().padLeft(2, '0')} - ${entry.message}",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: entry.color),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiagnosticEntry {
  final TimeOfDay time;
  final String message;
  final Color color;
  _DiagnosticEntry({required this.time, required this.message, required this.color});
}
    _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
    _checkKeyType(_keyController.text);
    setState(() {});
  }

  void _checkKeyType(String key) {
    setState(() {
      _isServiceRole = key.contains("service_role");
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _diagnostics = [];
      _statusMessage = 'بدء عملية التشخيص الشاملة...';
      _statusColor = Colors.blue;
    });

    try {
      // 1. فحص اتصال الهاتف بالإنترنت (Connectivity)
      _addLog("📡 فحص اتصال الهاتف...");
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        throw "الهاتف غير متصل بالإنترنت. يرجى تفعيل الواي فاي أو البيانات.";
      }
      _addLog("✅ الهاتف متصل بالشبكة.");

      // 2. فحص الوصول إلى Google (للتأكد من وجود إنترنت حقيقي)
      _addLog("🌍 فحص الوصول للإنترنت العالمي...");
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) throw "لا يوجد إنترنت";
      } catch (_) {
        throw "الشبكة متصلة ولكن لا يوجد إنترنت فعلي (No Internet Access).";
      }

      // 3. تحليل الرابط و DNS الخاص بـ Supabase
      _addLog("🔍 تحليل رابط السيرفر...");
      String url = _urlController.text.trim();
      if (!url.startsWith("https://")) throw "الرابط يجب أن يبدأ بـ https://";
      
      Uri uri = Uri.parse(url);
      try {
        await InternetAddress.lookup(uri.host);
        _addLog("✅ تم العثور على عنوان السيرفر (DNS OK).");
      } catch (_) {
        throw "فشل في العثور على السيرفر (Failed host lookup). تأكد من صحة الرابط أو إعدادات الشبكة في إب.";
      }

      // 4. اختبار الاتصال الفعلي بـ Supabase (Rest API)
      _addLog("🔑 اختبار صلاحية المفتاح والاتصال...");
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await dio.get(
        '$url/rest/v1/', // طلب معلومات الـ Schema للتأكد من الصلاحية
        options: Options(headers: {
          'apikey': _keyController.text.trim(),
          'Authorization': 'Bearer ${_keyController.text.trim()}',
        }),
      );

      if (response.statusCode == 200) {
        _addLog("✅ تم الاتصال بنجاح. السيرفر مستجيب.");
        setState(() {
          _statusMessage = "تم الاتصال بنجاح! 🎉";
          _statusColor = Colors.green;
        });
      }

    } catch (e) {
      _addLog("❌ خطأ: $e");
      setState(() {
        _statusMessage = "فشل الاتصال";
        _statusColor = Colors.red;
      });
      _showErrorDetail(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addLog(String message) {
    setState(() => _diagnostics.add("${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $message"));
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_supabase_url', _urlController.text.trim());
    await prefs.setString('custom_supabase_key', _keyController.text.trim());
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تم الحفظ'),
        content: const Text('تم تحديث إعدادات الاتصال بنجاح. يرجى إغلاق التطبيق وفتحه مجدداً لتطبيق التغييرات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق'))
        ],
      ),
    );
  }

  void _showErrorDetail(String error) {
    String advice = "تأكد من الرابط والمفتاح.";
    if (error.contains("Failed host lookup")) advice = "مشكلة في الـ DNS. جرب إيقاف الـ VPN أو تغيير الشبكة.";
    if (error.contains("401")) advice = "المفتاح غير صالح (Unauthorized).";
    if (error.contains("403")) advice = "مرفوض (Forbidden). تأكد من إعدادات RLS في Supabase.";
    
    _addLog("💡 نصيحة: $advice");
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مهندس الاتصال الذكي'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCurrentSettings),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Theme.of(context).primaryColor.withOpacity(0.05), Colors.white],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // بطاقة الإعدادات
                  _buildSettingsCard(),
                  const SizedBox(height: 20),
                  
                  // أزرار التحكم
                  _buildActionButtons(),
                  const SizedBox(height: 20),

                  // شاشة التشخيص (Log Viewer)
                  _buildDiagnosticsPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings_remote, color: Colors.blue),
                SizedBox(width: 8),
                Text('إعدادات الخادم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'رابط Supabase URL',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _keyController,
              maxLines: 3,
              onChanged: _checkKeyType,
              decoration: InputDecoration(
                labelText: 'مفتاح API',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: _isServiceRole 
                  ? const Tooltip(message: 'مفتاح أدمن (Service Role)', child: Icon(Icons.verified_user, color: Colors.orange))
                  : null,
              ),
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
            onPressed: _isLoading ? null : _testConnection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.bolt),
            label: const Text('تشخيص الاتصال'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات'),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('تقرير التشخيص:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _statusColor.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: _statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(_statusMessage, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _diagnostics.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _diagnostics[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
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
