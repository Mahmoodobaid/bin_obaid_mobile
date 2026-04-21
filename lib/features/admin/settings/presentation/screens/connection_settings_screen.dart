import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../core/config/config.dart';

enum ConnectionStateType { idle, loading, success, error }

class ConnectionSettingsScreen extends ConsumerStatefulWidget {
  const ConnectionSettingsScreen({super.key});
  @override
  ConsumerState<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends ConsumerState<ConnectionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _schemaController = TextEditingController();
  final _tableController = TextEditingController();
  final _timeoutController = TextEditingController();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _showKey = false;
  bool _autoRetry = true;
  bool _useHttpsOnly = true;
  bool _useServiceRole = false;

  ConnectionStateType _connectionState = ConnectionStateType.idle;
  String _connectionStatus = 'لم يتم اختبار الاتصال بعد';
  String _connectionDetails = '';
  int? _statusCode;
  int? _responseTime;
  bool _hasInternet = false;
  bool _dnsWorking = false;
  bool _apiReachable = false;
  bool _dbAccessible = false;

  List<String> _permissionResults = [];
  List<String> _connectionLogs = [];

  String _deviceInfo = '';
  String _appInfo = '';
  String _currentKeyType = 'anon';
  String _pingResult = '';
  String _dnsResult = '';
  String _connectionQuality = '';

  Color get _statusColor {
    switch (_connectionState) {
      case ConnectionStateType.success: return Colors.green;
      case ConnectionStateType.error: return Colors.red;
      case ConnectionStateType.loading: return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (_connectionState) {
      case ConnectionStateType.success: return Icons.check_circle;
      case ConnectionStateType.error: return Icons.error;
      case ConnectionStateType.loading: return Icons.sync;
      default: return Icons.info_outline;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _listenConnectivity();
    _getDeviceAndAppInfo();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _urlController.dispose();
    _keyController.dispose();
    _schemaController.dispose();
    _tableController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _listenConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _checkInternetAvailability();
    });
  }

  Future<void> _getDeviceAndAppInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    String deviceData = '';
    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceData = 'Android ${android.version.release} (SDK ${android.version.sdkInt}), ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceData = 'iOS ${ios.systemVersion}, ${ios.model}';
      } else {
        deviceData = 'Unknown Platform';
      }
    } catch (_) { deviceData = 'غير معروف'; }
    if (!mounted) return;
    setState(() {
      _deviceInfo = deviceData;
      _appInfo = '${packageInfo.appName} v${packageInfo.version} (${packageInfo.packageName})';
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _urlController.text = prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;
    _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
    _schemaController.text = prefs.getString('custom_supabase_schema') ?? 'public';
    _tableController.text = prefs.getString('custom_test_table') ?? 'products';
    _timeoutController.text = prefs.getInt('custom_connection_timeout')?.toString() ?? '15';
    _autoRetry = prefs.getBool('custom_auto_retry') ?? true;
    _useHttpsOnly = prefs.getBool('custom_https_only') ?? true;
    _useServiceRole = prefs.getBool('custom_use_service_role') ?? false;
    // لا نستعيد مفتاح service_role من التخزين الدائم، نستخدم فقط anon key المحفوظ
    if (!_useServiceRole) {
      _keyController.text = prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;
    } else {
      // إذا كان المستخدم يريد استخدام service_role، نضعه مؤقتًا دون حفظه
      _keyController.text = AppConfig.supabaseServiceKey;
    }
    _updateKeyType();
    await _checkInternetAvailability();
    if (!mounted) return;
    setState(() {});
  }

  void _updateKeyType() {
    final key = _keyController.text.trim();
    _currentKeyType = key.contains('service_role') ? 'service_role' : 'anon';
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_supabase_url', _urlController.text.trim());
      // لا نحفظ مفتاح service_role أبدًا في SharedPreferences
      if (!_useServiceRole) {
        await prefs.setString('custom_supabase_key', _keyController.text.trim());
      }
      await prefs.setString('custom_supabase_schema', _schemaController.text.trim());
      await prefs.setString('custom_test_table', _tableController.text.trim());
      await prefs.setInt('custom_connection_timeout', int.tryParse(_timeoutController.text.trim()) ?? 15);
      await prefs.setBool('custom_auto_retry', _autoRetry);
      await prefs.setBool('custom_https_only', _useHttpsOnly);
      await prefs.setBool('custom_use_service_role', _useServiceRole);
      _updateKeyType();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ إعدادات الاتصال بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) _showError('فشل حفظ الإعدادات', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetToDefault() async {
    _urlController.text = AppConfig.supabaseUrl;
    _keyController.text = AppConfig.supabaseAnonKey;
    _schemaController.text = 'public';
    _tableController.text = 'products';
    _timeoutController.text = '15';
    setState(() {
      _autoRetry = true;
      _useHttpsOnly = true;
      _useServiceRole = false;
    });
    _updateKeyType();
  }

  Future<void> _toggleKeyType() async {
    setState(() {
      if (_useServiceRole) {
        _keyController.text = AppConfig.supabaseAnonKey;
        _useServiceRole = false;
      } else {
        _keyController.text = AppConfig.supabaseServiceKey;
        _useServiceRole = true;
      }
      _updateKeyType();
    });
    // لا نحفظ التغيير تلقائيًا، بل نترك المستخدم يضغط "حفظ" إذا أراد الاحتفاظ بالإعدادات
  }

  Future<void> _copyKey() async {
    await Clipboard.setData(ClipboardData(text: _keyController.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 تم نسخ المفتاح')));
  }

  Future<void> _checkInternetAvailability() async {
    final List<ConnectivityResult> result = await Connectivity().checkConnectivity();
    _hasInternet = result.any((r) => r != ConnectivityResult.none);
    try {
      final lookup = await InternetAddress.lookup('google.com');
      _dnsWorking = lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      _dnsWorking = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkPermissions() async {
    _permissionResults.clear();
    final camera = await Permission.camera.status;
    final photos = await Permission.photos.status;
    final storage = await Permission.storage.status;
    final manageStorage = await Permission.manageExternalStorage.status;
    final notification = await Permission.notification.status;

    _permissionResults.add('الكاميرا: ${camera.isGranted ? 'مسموح' : 'غير مسموح'}');
    _permissionResults.add('الصور: ${photos.isGranted ? 'مسموح' : 'غير مسموح'}');
    _permissionResults.add('التخزين: ${storage.isGranted ? 'مسموح' : 'غير مسموح'}');
    _permissionResults.add('إدارة التخزين: ${manageStorage.isGranted ? 'مسموح' : 'غير مسموح'}');
    _permissionResults.add('الإشعارات: ${notification.isGranted ? 'مسموح' : 'غير مسموح'}');
    if (mounted) setState(() {});
  }

  Future<void> _requestAllPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.notification,
      Permission.manageExternalStorage,
    ].request();
    await _checkPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم طلب جميع الصلاحيات'), backgroundColor: Colors.green));
    }
  }

  Future<void> _openAppSettings() async => await openAppSettings();

  Future<void> _autoFix() async {
    await _resetToDefault();
    await _testConnection();
  }

  Future<void> _clearLogs() async {
    setState(() => _connectionLogs.clear());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🧹 تم حذف جميع السجلات'), backgroundColor: Colors.orange));
  }

  Future<void> _copyLogs() async {
    final logs = _connectionLogs.join('\n');
    await Clipboard.setData(ClipboardData(text: logs));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 تم نسخ السجلات'), backgroundColor: Colors.green));
  }

  Future<void> _exportReportToFile() async {
    final report = _generateFullReport();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/bin_obaid_connection_report.txt');
      await file.writeAsString(report);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📄 تم حفظ التقرير في:\n${file.path}'), backgroundColor: Colors.green, duration: const Duration(seconds: 5)));
    } catch (e) {
      if (mounted) _showError('فشل تصدير التقرير', e.toString());
    }
  }

  void _updateConnectionQuality(int responseTime) {
    if (!_hasInternet || !_dnsWorking) {
      _connectionQuality = 'منقطع';
      return;
    }
    if (responseTime < 150) {
      _connectionQuality = 'ممتاز جداً';
    } else if (responseTime < 400) {
      _connectionQuality = 'ممتاز';
    } else if (responseTime < 800) {
      _connectionQuality = 'جيد';
    } else if (responseTime < 1500) {
      _connectionQuality = 'ضعيف';
    } else {
      _connectionQuality = 'ضعيف جداً';
    }
  }

  Future<void> _testPing() async {
    setState(() => _pingResult = 'جاري اختبار ping...');
    try {
      final uri = Uri.tryParse(_urlController.text.trim());
      if (uri == null) throw Exception('رابط غير صالح');
      final result = await InternetAddress.lookup(uri.host);
      if (result.isNotEmpty) {
        setState(() => _pingResult = '✅ نجح ping: ${result.first.address}');
      } else {
        setState(() => _pingResult = '❌ فشل ping: لا توجد عناوين IP');
      }
    } catch (e) {
      setState(() => _pingResult = '❌ فشل ping: $e');
    }
  }

  Future<void> _testDns() async {
    setState(() => _dnsResult = 'جاري اختبار DNS...');
    try {
      final uri = Uri.tryParse(_urlController.text.trim());
      if (uri == null) throw Exception('رابط غير صالح');
      final result = await InternetAddress.lookup(uri.host);
      if (result.isNotEmpty) {
        setState(() {
          _dnsResult = '✅ DNS يعمل: ${result.map((e) => e.address).join(', ')}';
          _dnsWorking = true;
        });
      } else {
        setState(() {
          _dnsResult = '❌ فشل DNS: لا توجد عناوين IP';
          _dnsWorking = false;
        });
      }
    } catch (e) {
      setState(() {
        _dnsResult = '❌ فشل DNS: $e';
        _dnsWorking = false;
      });
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_supabase_url');
      await prefs.remove('custom_supabase_key');
      await prefs.remove('custom_supabase_schema');
      await prefs.remove('custom_test_table');
      await prefs.remove('custom_connection_timeout');
      await prefs.remove('custom_auto_retry');
      await prefs.remove('custom_https_only');
      await prefs.remove('custom_use_service_role');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🧹 تم مسح إعدادات الاتصال المحفوظة'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) _showError('فشل مسح الكاش', e.toString());
    }
  }

  String _generateFullReport() {
    final buffer = StringBuffer();
    final now = DateTime.now();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('📱 تقرير تشخيص الاتصال - بن عبيد التجارية');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('📅 التاريخ والوقت: ${now.toString()}');
    buffer.writeln('');
    buffer.writeln('📌 معلومات الجهاز والتطبيق:');
    buffer.writeln('   ${_deviceInfo}');
    buffer.writeln('   ${_appInfo}');
    buffer.writeln('');
    buffer.writeln('🌐 حالة الشبكة:');
    buffer.writeln('   الإنترنت: ${_hasInternet ? 'متصل' : 'غير متصل'}');
    buffer.writeln('   DNS: ${_dnsWorking ? 'يعمل' : 'لا يعمل'}');
    buffer.writeln('   Ping: ${_pingResult.isNotEmpty ? _pingResult : 'لم يتم الاختبار'}');
    buffer.writeln('   جودة الاتصال: ${_connectionQuality.isNotEmpty ? _connectionQuality : 'غير معروفة'}');
    buffer.writeln('');
    buffer.writeln('🔧 إعدادات الخادم:');
    buffer.writeln('   الرابط: ${_urlController.text}');
    buffer.writeln('   المخطط (Schema): ${_schemaController.text}');
    buffer.writeln('   جدول الاختبار: ${_tableController.text}');
    buffer.writeln('   مهلة الاتصال: ${_timeoutController.text} ثانية');
    buffer.writeln('');
    buffer.writeln('🔑 تحليل المفتاح:');
    buffer.writeln('   نوع المفتاح: $_currentKeyType');
    buffer.writeln('   طول المفتاح: ${_keyController.text.length} حرفاً');
    buffer.writeln('');
    buffer.writeln('⚙️ الخيارات:');
    buffer.writeln('   HTTPS فقط: ${_useHttpsOnly ? 'مفعل' : 'غير مفعل'}');
    buffer.writeln('   إعادة المحاولة تلقائياً: ${_autoRetry ? 'مفعل' : 'غير مفعل'}');
    buffer.writeln('');
    buffer.writeln('📊 نتيجة آخر اختبار:');
    buffer.writeln('   الحالة: $_connectionStatus');
    buffer.writeln('   التفاصيل: $_connectionDetails');
    if (_statusCode != null) buffer.writeln('   كود HTTP: $_statusCode');
    if (_responseTime != null) buffer.writeln('   زمن الاستجابة: $_responseTime ms');
    buffer.writeln('   API متاح: ${_apiReachable ? 'نعم' : 'لا'}');
    buffer.writeln('   قاعدة البيانات: ${_dbAccessible ? 'متاحة' : 'غير متاحة'}');
    buffer.writeln('');
    buffer.writeln('🛡️ الصلاحيات:');
    for (final p in _permissionResults) buffer.writeln('   • $p');
    buffer.writeln('');
    buffer.writeln('📋 سجل العمليات:');
    if (_connectionLogs.isEmpty) {
      buffer.writeln('   (لا يوجد سجل)');
    } else {
      for (final log in _connectionLogs) buffer.writeln('   • $log');
    }
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('نهاية التقرير');
    return buffer.toString();
  }

  Future<void> _copyFullReport() async {
    await Clipboard.setData(ClipboardData(text: _generateFullReport()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 تم نسخ التقرير الكامل إلى الحافظة'), backgroundColor: Colors.green));
  }

  Future<void> _shareReport() async {
    await Share.share(_generateFullReport(), subject: 'تقرير تشخيص الاتصال - بن عبيد');
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _connectionState = ConnectionStateType.loading;
      _connectionStatus = 'جاري اختبار الاتصال...';
      _connectionDetails = 'يتم الآن فحص الإنترنت والخادم وقاعدة البيانات';
      _connectionLogs.clear();
      _dbAccessible = false;
      _apiReachable = false;
    });
    final stopwatch = Stopwatch()..start();
    try {
      await _checkInternetAvailability();
      await _checkPermissions();
      if (!_hasInternet) throw Exception('لا يوجد اتصال بالإنترنت');
      final url = _urlController.text.trim();
      final key = _keyController.text.trim();
      final schema = _schemaController.text.trim();
      final table = _tableController.text.trim();
      final timeout = int.tryParse(_timeoutController.text.trim()) ?? 15;
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) throw Exception('الرابط غير صالح');
      if (_useHttpsOnly && !url.startsWith('https://')) throw Exception('يجب أن يبدأ الرابط بـ https://');
      _connectionLogs.add('[${DateTime.now().toIso8601String()}] فحص رابط الخادم');
      final dio = Dio(BaseOptions(
        connectTimeout: Duration(seconds: timeout),
        receiveTimeout: Duration(seconds: timeout),
        sendTimeout: Duration(seconds: timeout),
        headers: {'apikey': key, 'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
      ));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) { _connectionLogs.add('[${DateTime.now().toIso8601String()}] إرسال طلب إلى: ${o.uri}'); h.next(o); },
        onResponse: (r, h) { _connectionLogs.add('[${DateTime.now().toIso8601String()}] تم استلام الاستجابة: ${r.statusCode}'); h.next(r); },
        onError: (e, h) { _connectionLogs.add('[${DateTime.now().toIso8601String()}] خطأ: ${e.message}'); h.next(e); },
      ));
      final response = await dio.get('$url/rest/v1/$table?select=*&limit=1',
          options: Options(headers: {'Accept-Profile': schema, 'Content-Profile': schema}));
      stopwatch.stop();
      _responseTime = stopwatch.elapsedMilliseconds;
      _statusCode = response.statusCode;
      _apiReachable = true;
      _updateConnectionQuality(_responseTime!);
      if (response.statusCode == 200 || response.statusCode == 206) {
        _dbAccessible = true;
        if (!mounted) return;
        setState(() {
          _connectionState = ConnectionStateType.success;
          _connectionStatus = '✅ الاتصال ناجح';
          _connectionDetails = 'الخادم يعمل بشكل طبيعي\nالاستجابة: ${response.statusCode}\nالوقت: $_responseTime ms\nجودة الاتصال: $_connectionQuality\nعدد السجلات: ${(response.data as List).length}';
        });
      } else {
        throw Exception('كود استجابة غير متوقع: ${response.statusCode}');
      }
    } on DioException catch (e) {
      stopwatch.stop();
      if (mounted) _showError('فشل اختبار الاتصال', _analyzeHttpError(e));
    } catch (e) {
      stopwatch.stop();
      if (mounted) _showError('فشل اختبار الاتصال', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _analyzeHttpError(DioException e) {
    final code = e.response?.statusCode;
    switch (code) {
      case 400: return 'طلب غير صالح (400)';
      case 401: return 'غير مصرح (401) - المفتاح خاطئ';
      case 403: return 'محظور (403) - صلاحيات RLS';
      case 404: return 'غير موجود (404) - تحقق من الجدول';
      case 406: return 'غير مقبول (406) - المخطط (schema) غير صحيح';
      case 429: return 'طلبات كثيرة (429)';
      case 500: return 'خطأ خادم (500)';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout: return 'انتهت مهلة الاتصال بالخادم';
      case DioExceptionType.receiveTimeout: return 'انتهت مهلة استقبال البيانات';
      case DioExceptionType.sendTimeout: return 'انتهت مهلة إرسال البيانات';
      case DioExceptionType.badCertificate: return 'شهادة SSL غير صالحة';
      case DioExceptionType.connectionError: return 'تعذر الوصول إلى الخادم';
      default: return e.message ?? 'خطأ غير معروف';
    }
  }

  void _showError(String title, String details) {
    if (!mounted) return;
    setState(() {
      _connectionState = ConnectionStateType.error;
      _connectionStatus = '❌ $title';
      _connectionDetails = details;
      _apiReachable = false;
      _dbAccessible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الاتصال بقاعدة البيانات'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'share') await _shareReport();
                else if (v == 'copy') await _copyFullReport();
                else if (v == 'export') await _exportReportToFile();
                else if (v == 'reset') await _resetToDefault();
              },
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share), SizedBox(width:8), Text('مشاركة التقرير')])),
                const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_all), SizedBox(width:8), Text('نسخ التقرير')])),
                const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.save_alt), SizedBox(width:8), Text('تصدير إلى ملف')])),
                const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.restore), SizedBox(width:8), Text('استعادة الإعدادات')])),
              ],
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Card(elevation:4, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)), child:Padding(padding: const EdgeInsets.all(20), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Row(children:[
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.cloud, color: Colors.blue)),
                const SizedBox(width:12),
                const Text('إعدادات الخادم', style: TextStyle(fontSize:18, fontWeight:FontWeight.bold)),
                const Spacer(),
                Chip(
                  avatar: Icon(
                    _currentKeyType == 'service_role' ? Icons.admin_panel_settings : Icons.person,
                    size: 18,
                  ),
                  label: Text(_currentKeyType == 'service_role' ? 'مدير' : 'عميل'),
                  backgroundColor: _currentKeyType == 'service_role' ? Colors.orange.shade100 : Colors.blue.shade100,
                ),
                IconButton(onPressed:_copyKey, icon:const Icon(Icons.copy), tooltip:'نسخ المفتاح'),
                IconButton(onPressed:_toggleKeyType, icon:Icon(_useServiceRole?Icons.security:Icons.vpn_key), tooltip:_useServiceRole?'التبديل إلى anon':'التبديل إلى service_role'),
              ]),
              const SizedBox(height:20),
              TextFormField(controller:_urlController, decoration:InputDecoration(labelText:'رابط Supabase', border:OutlineInputBorder(borderRadius:BorderRadius.circular(16))), validator:(v)=>v==null||v.isEmpty?'أدخل الرابط':Uri.tryParse(v)?.hasScheme!=true?'رابط غير صالح':null),
              const SizedBox(height:16),
              TextFormField(controller:_keyController, obscureText:!_showKey, maxLines:_showKey?4:1, decoration:InputDecoration(labelText:'مفتاح API', border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)), suffixIcon:IconButton(onPressed:()=>setState(()=>_showKey=!_showKey), icon:Icon(_showKey?Icons.visibility_off:Icons.visibility))), validator:(v)=>v==null||v.isEmpty?'أدخل المفتاح':v.length<20?'المفتاح قصير':null),
              if(_useServiceRole) Container(margin:const EdgeInsets.only(top:8), padding:const EdgeInsets.all(12), decoration:BoxDecoration(color:Colors.orange.withOpacity(0.1), borderRadius:BorderRadius.circular(12), border:Border.all(color:Colors.orange)), child:Row(children:[const Icon(Icons.warning, color:Colors.orange), const SizedBox(width:8), Expanded(child:Text('⚠️ مفتاح الخدمة يتجاوز الأمان. للتشخيص فقط.', style:TextStyle(color:Colors.orange.shade700, fontSize:12)))])),
              const SizedBox(height:16),
              Row(children:[Expanded(child:TextFormField(controller:_schemaController, decoration:const InputDecoration(labelText:'Schema'))), const SizedBox(width:12), Expanded(child:TextFormField(controller:_tableController, decoration:const InputDecoration(labelText:'جدول الاختبار')))]),
              const SizedBox(height:16),
              TextFormField(controller:_timeoutController, keyboardType:TextInputType.number, decoration:const InputDecoration(labelText:'مهلة الاتصال بالثواني')),
            ]))),
            const SizedBox(height:20),
            Card(elevation:4, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)), child:Padding(padding: const EdgeInsets.all(20), child:Column(children:[
              SwitchListTile(value:_useHttpsOnly, onChanged:(v)=>setState(()=>_useHttpsOnly=v), title:const Text('السماح فقط بروابط HTTPS'), contentPadding:EdgeInsets.zero),
              SwitchListTile(value:_autoRetry, onChanged:(v)=>setState(()=>_autoRetry=v), title:const Text('إعادة المحاولة تلقائياً'), contentPadding:EdgeInsets.zero),
            ]))),
            const SizedBox(height:20),
            Wrap(spacing:8, runSpacing:8, children:[
              ElevatedButton.icon(onPressed:_isLoading?null:_testConnection, icon:_isLoading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.wifi_find), label:const Text('اختبار الاتصال'), style:ElevatedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12))),
              ElevatedButton.icon(onPressed:_isSaving?null:_saveSettings, icon:_isSaving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save), label:const Text('حفظ الإعدادات'), style:ElevatedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12))),
              OutlinedButton.icon(onPressed:_autoFix, icon:const Icon(Icons.auto_fix_high), label:const Text('إصلاح تلقائي')),
              OutlinedButton.icon(onPressed:_requestAllPermissions, icon:const Icon(Icons.security), label:const Text('طلب الصلاحيات')),
              OutlinedButton.icon(onPressed:_openAppSettings, icon:const Icon(Icons.settings), label:const Text('إعدادات التطبيق')),
              OutlinedButton.icon(onPressed:_getDeviceAndAppInfo, icon:const Icon(Icons.info), label:const Text('تحديث معلومات الجهاز')),
            ]),
            const SizedBox(height:12),
            Wrap(spacing:8, runSpacing:8, children:[
              OutlinedButton.icon(onPressed:_testPing, icon:const Icon(Icons.network_ping), label:const Text('Ping')),
              OutlinedButton.icon(onPressed:_testDns, icon:const Icon(Icons.dns), label:const Text('DNS')),
              OutlinedButton.icon(onPressed:_clearCache, icon:const Icon(Icons.cleaning_services), label:const Text('مسح الكاش')),
              OutlinedButton.icon(onPressed:_clearLogs, icon:const Icon(Icons.delete_sweep), label:const Text('حذف السجلات')),
              OutlinedButton.icon(onPressed:_copyLogs, icon:const Icon(Icons.copy), label:const Text('نسخ السجلات')),
            ]),
            const SizedBox(height:20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds:300),
              child: Container(
                key: ValueKey(_connectionState),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                  Row(children:[
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_statusIcon, color: _statusColor)),
                    const SizedBox(width:12),
                    Expanded(child: Text(_connectionStatus, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize:16))),
                  ]),
                  if (_isLoading) ...[
                    const SizedBox(height:16),
                    LinearProgressIndicator(color: _statusColor),
                  ],
                  if (_connectionDetails.isNotEmpty) ...[
                    const SizedBox(height:16),
                    SelectableText(_connectionDetails, style: const TextStyle(fontSize:14)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height:20),
            ExpansionTile(title: const Text('معلومات متقدمة'), leading: const Icon(Icons.info_outline), children: [
              Card(elevation:4, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)), child:Padding(padding: const EdgeInsets.all(20), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                const Text('حالة الشبكة والصلاحيات', style:TextStyle(fontWeight:FontWeight.bold)),
                const SizedBox(height:12),
                _buildStatusRow('الإنترنت', _hasInternet),
                _buildStatusRow('DNS', _dnsWorking),
                _buildStatusRow('API', _apiReachable),
                _buildStatusRow('قاعدة البيانات', _dbAccessible),
                if (_connectionQuality.isNotEmpty) Text('جودة الاتصال: $_connectionQuality'),
                if (_statusCode != null) Text('HTTP Status: $_statusCode'),
                if (_responseTime != null) Text('زمن الاستجابة: $_responseTime ms'),
                if (_pingResult.isNotEmpty) Text(_pingResult),
                if (_dnsResult.isNotEmpty) Text(_dnsResult),
                const Divider(height:24),
                ..._permissionResults.map((item) => Padding(padding: const EdgeInsets.only(bottom:6), child: Text('• $item'))),
              ]))),
              if (_connectionLogs.isNotEmpty)
                Card(elevation:4, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)), child:Padding(padding: const EdgeInsets.all(20), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                  const Text('سجل العمليات', style:TextStyle(fontWeight:FontWeight.bold)),
                  const SizedBox(height:12),
                  ..._connectionLogs.map((log) => Padding(padding: const EdgeInsets.only(bottom:8), child: SelectableText('• $log'))),
                ]))),
            ]),
            const SizedBox(height:32),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.only(bottom:6),
      child: Row(children: [
        SizedBox(width:100, child: Text('$label:')),
        Icon(status ? Icons.check_circle : Icons.error, color: status ? Colors.green : Colors.red, size:18),
        const SizedBox(width:6),
        Text(status ? 'يعمل' : 'لا يعمل'),
      ]),
    );
  }
}