import 'dart:async';
import 'dart:convert';
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

import '../../../../../core/config/config.dart';

class ConnectionSettingsScreen extends ConsumerStatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  ConsumerState<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState
    extends ConsumerState<ConnectionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _schemaController = TextEditingController();
  final TextEditingController _tableController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _showKey = false;
  bool _autoRetry = true;
  bool _useHttpsOnly = true;
  bool _useServiceRole = false; // للتشخيص

  String _connectionStatus = 'لم يتم اختبار الاتصال بعد';
  String _connectionDetails = '';
  Color _statusColor = Colors.grey;
  IconData _statusIcon = Icons.info_outline;

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

  // متغيرات إضافية للتشخيص المتقدم
  String _currentKeyType = 'anon';
  String _pingResult = '';
  String _dnsResult = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _listenConnectivity();
    _getDeviceAndAppInfo();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _schemaController.dispose();
    _tableController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((event) {
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
        deviceData =
            'Android ${android.version.release} (SDK ${android.version.sdkInt}), ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceData = 'iOS ${ios.systemVersion}, ${ios.model}';
      } else {
        deviceData = 'Unknown Platform';
      }
    } catch (_) {
      deviceData = 'غير معروف';
    }

    setState(() {
      _deviceInfo = deviceData;
      _appInfo =
          '${packageInfo.appName} v${packageInfo.version} (${packageInfo.packageName})';
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _urlController.text =
        prefs.getString('custom_supabase_url') ?? AppConfig.supabaseUrl;

    _keyController.text =
        prefs.getString('custom_supabase_key') ?? AppConfig.supabaseAnonKey;

    _schemaController.text =
        prefs.getString('custom_supabase_schema') ?? 'public';

    _tableController.text =
        prefs.getString('custom_test_table') ?? 'products';

    _timeoutController.text =
        prefs.getInt('custom_connection_timeout')?.toString() ?? '15';

    _autoRetry = prefs.getBool('custom_auto_retry') ?? true;
    _useHttpsOnly = prefs.getBool('custom_https_only') ?? true;
    _useServiceRole = prefs.getBool('custom_use_service_role') ?? false;

    // تحديد نوع المفتاح الحالي
    _updateKeyType();

    await _checkInternetAvailability();

    if (mounted) setState(() {});
  }

  void _updateKeyType() {
    final key = _keyController.text.trim();
    if (key.contains('service_role')) {
      _currentKeyType = 'service_role';
    } else {
      _currentKeyType = 'anon';
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'custom_supabase_url',
        _urlController.text.trim(),
      );

      await prefs.setString(
        'custom_supabase_key',
        _keyController.text.trim(),
      );

      await prefs.setString(
        'custom_supabase_schema',
        _schemaController.text.trim(),
      );

      await prefs.setString(
        'custom_test_table',
        _tableController.text.trim(),
      );

      await prefs.setInt(
        'custom_connection_timeout',
        int.tryParse(_timeoutController.text.trim()) ?? 15,
      );

      await prefs.setBool('custom_auto_retry', _autoRetry);
      await prefs.setBool('custom_https_only', _useHttpsOnly);
      await prefs.setBool('custom_use_service_role', _useServiceRole);

      _updateKeyType();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ إعدادات الاتصال بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('فشل حفظ الإعدادات', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _resetToDefault() async {
    _urlController.text = AppConfig.supabaseUrl;
    _keyController.text = AppConfig.supabaseAnonKey;
    _schemaController.text = 'public';
    _tableController.text = 'products';
    _timeoutController.text = '15';
    _autoRetry = true;
    _useHttpsOnly = true;
    _useServiceRole = false;
    _updateKeyType();

    setState(() {});
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

    await _saveSettings();
  }

  Future<void> _copyKey() async {
    await Clipboard.setData(
      ClipboardData(text: _keyController.text.trim()),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 تم نسخ المفتاح'),
        ),
      );
    }
  }

  Future<void> _checkInternetAvailability() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _hasInternet = connectivityResult != ConnectivityResult.none;

      try {
        final result = await InternetAddress.lookup('google.com');
        _dnsWorking = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        _dnsWorking = false;
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _checkPermissions() async {
    _permissionResults.clear();

    final internetStatus = await Permission.phone.status;
    final storageStatus = await Permission.storage.status;
    final notificationStatus = await Permission.notification.status;

    _permissionResults.add(
      'الإنترنت: ${internetStatus.isGranted ? 'مسموح' : 'غير مسموح'}',
    );

    _permissionResults.add(
      'التخزين: ${storageStatus.isGranted ? 'مسموح' : 'غير مسموح'}',
    );

    _permissionResults.add(
      'الإشعارات: ${notificationStatus.isGranted ? 'مسموح' : 'غير مسموح'}',
    );

    setState(() {});
  }

  /// اختبار الاتصال بخادم معين (ping)
  Future<void> _testPing() async {
    setState(() {
      _pingResult = 'جاري اختبار ping...';
    });

    try {
      final url = _urlController.text.trim();
      final uri = Uri.parse(url);
      final host = uri.host;

      final result = await InternetAddress.lookup(host);
      if (result.isNotEmpty) {
        setState(() {
          _pingResult = '✅ نجح ping: ${result.first.address}';
        });
      } else {
        setState(() {
          _pingResult = '❌ فشل ping: لا توجد عناوين IP';
        });
      }
    } catch (e) {
      setState(() {
        _pingResult = '❌ فشل ping: $e';
      });
    }
  }

  /// اختبار DNS
  Future<void> _testDns() async {
    setState(() {
      _dnsResult = 'جاري اختبار DNS...';
    });

    try {
      final url = _urlController.text.trim();
      final uri = Uri.parse(url);
      final host = uri.host;

      final result = await InternetAddress.lookup(host);
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

  /// مسح الكاش المحلي
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧹 تم مسح الكاش المحلي'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _showError('فشل مسح الكاش', e.toString());
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
    if (_statusCode != null) {
      buffer.writeln('   كود HTTP: $_statusCode');
    }
    if (_responseTime != null) {
      buffer.writeln('   زمن الاستجابة: $_responseTime ms');
    }
    buffer.writeln('   API متاح: ${_apiReachable ? 'نعم' : 'لا'}');
    buffer.writeln('   قاعدة البيانات: ${_dbAccessible ? 'متاحة' : 'غير متاحة'}');
    buffer.writeln('');
    buffer.writeln('🛡️ الصلاحيات:');
    for (final p in _permissionResults) {
      buffer.writeln('   • $p');
    }
    buffer.writeln('');
    buffer.writeln('📋 سجل العمليات:');
    if (_connectionLogs.isEmpty) {
      buffer.writeln('   (لا يوجد سجل)');
    } else {
      for (final log in _connectionLogs) {
        buffer.writeln('   • $log');
      }
    }
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('نهاية التقرير');

    return buffer.toString();
  }

  Future<void> _copyFullReport() async {
    final report = _generateFullReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 تم نسخ التقرير الكامل إلى الحافظة'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _shareReport() async {
    final report = _generateFullReport();
    await Share.share(report, subject: 'تقرير تشخيص الاتصال - بن عبيد');
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _connectionStatus = 'جاري اختبار الاتصال...';
      _connectionDetails = 'يتم الآن فحص الإنترنت والخادم وقاعدة البيانات';
      _statusColor = Colors.orange;
      _statusIcon = Icons.sync;
      _connectionLogs.clear();
      _dbAccessible = false;
      _apiReachable = false;
    });

    final stopwatch = Stopwatch()..start();

    try {
      await _checkInternetAvailability();
      await _checkPermissions();

      if (!_hasInternet) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      final url = _urlController.text.trim();
      final key = _keyController.text.trim();
      final schema = _schemaController.text.trim();
      final table = _tableController.text.trim();
      final timeout = int.tryParse(_timeoutController.text.trim()) ?? 15;

      if (_useHttpsOnly && !url.startsWith('https://')) {
        throw Exception('يجب أن يبدأ الرابط بـ https://');
      }

      _connectionLogs.add('فحص رابط الخادم');

      final dio = Dio(
        BaseOptions(
          connectTimeout: Duration(seconds: timeout),
          receiveTimeout: Duration(seconds: timeout),
          sendTimeout: Duration(seconds: timeout),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            _connectionLogs.add('إرسال طلب إلى: ${options.uri}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            _connectionLogs.add(
              'تم استلام الاستجابة: ${response.statusCode}',
            );
            handler.next(response);
          },
          onError: (error, handler) {
            _connectionLogs.add('خطأ: ${error.message}');
            handler.next(error);
          },
        ),
      );

      // اختبار API
      final response = await dio.get(
        '$url/rest/v1/$table?select=*&limit=1',
        options: Options(
          headers: {
            'Accept-Profile': schema,
            'Content-Profile': schema,
          },
        ),
      );

      stopwatch.stop();

      _responseTime = stopwatch.elapsedMilliseconds;
      _statusCode = response.statusCode;
      _apiReachable = true;

      if (response.statusCode == 200 || response.statusCode == 206) {
        final data = response.data as List;
        _dbAccessible = data.isNotEmpty || true; // حتى لو فارغة

        setState(() {
          _connectionStatus = '✅ الاتصال ناجح';
          _connectionDetails = '''
الخادم يعمل بشكل طبيعي
الاستجابة: ${response.statusCode}
الوقت: ${_responseTime} ms
عدد السجلات المرجعة: ${data.length}
DNS: ${_dnsWorking ? 'يعمل' : 'لا يعمل'}
الإنترنت: ${_hasInternet ? 'متصل' : 'غير متصل'}
''';
          _statusColor = Colors.green;
          _statusIcon = Icons.check_circle;
        });
      } else {
        throw Exception('كود استجابة غير متوقع: ${response.statusCode}');
      }
    } on DioException catch (e) {
      stopwatch.stop();

      String errorMessage = 'خطأ غير معروف';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage = 'انتهت مهلة الاتصال بالخادم';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage = 'انتهت مهلة استقبال البيانات';
          break;
        case DioExceptionType.badResponse:
          errorMessage =
              'الخادم أعاد خطأ: ${e.response?.statusCode}\n${e.response?.data}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'تعذر الوصول إلى الخادم';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'تم إلغاء الاتصال';
          break;
        default:
          errorMessage = e.message ?? 'حدث خطأ أثناء الاتصال';
      }

      _showError('فشل اختبار الاتصال', errorMessage);
    } catch (e) {
      stopwatch.stop();
      _showError('فشل اختبار الاتصال', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String title, String details) {
    setState(() {
      _connectionStatus = '❌ $title';
      _connectionDetails = details;
      _statusColor = Colors.red;
      _statusIcon = Icons.error;
      _apiReachable = false;
      _dbAccessible = false;
    });
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
    List<Widget>? actions,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actions != null) ...[
                  const Spacer(),
                  ...actions,
                ],
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الاتصال بقاعدة البيانات'),
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _shareReport,
              icon: const Icon(Icons.share),
              tooltip: 'مشاركة التقرير',
            ),
            IconButton(
              onPressed: _copyFullReport,
              icon: const Icon(Icons.copy_all),
              tooltip: 'نسخ التقرير الكامل',
            ),
            IconButton(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.restore),
              tooltip: 'استعادة الإعدادات الافتراضية',
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // بطاقة إعدادات الخادم
              _buildInfoCard(
                title: 'إعدادات الخادم',
                icon: Icons.cloud,
                actions: [
                  IconButton(
                    onPressed: _copyKey,
                    icon: const Icon(Icons.copy),
                    tooltip: 'نسخ المفتاح',
                  ),
                  IconButton(
                    onPressed: _toggleKeyType,
                    icon: Icon(
                      _useServiceRole ? Icons.security : Icons.vpn_key,
                    ),
                    tooltip: _useServiceRole
                        ? 'التبديل إلى مفتاح العميل (anon)'
                        : 'التبديل إلى مفتاح الخدمة (service_role)',
                  ),
                ],
                child: Column(
                  children: [
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'رابط Supabase',
                        hintText: 'https://your-project.supabase.co',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل رابط الخادم';
                        }
                        if (!value.startsWith('http')) {
                          return 'الرابط غير صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _keyController,
                      obscureText: !_showKey,
                      maxLines: _showKey ? 4 : 1,
                      decoration: InputDecoration(
                        labelText: 'مفتاح API',
                        hintText: _useServiceRole
                            ? 'مفتاح الخدمة (service_role)'
                            : 'مفتاح العميل (anon)',
                        prefixIcon: const Icon(Icons.key),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _showKey = !_showKey);
                          },
                          icon: Icon(
                            _showKey ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل مفتاح API';
                        }
                        if (value.trim().length < 20) {
                          return 'المفتاح قصير جداً';
                        }
                        return null;
                      },
                    ),
                    if (_useServiceRole)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ أنت تستخدم مفتاح الخدمة (service_role). هذا المفتاح يتجاوز جميع قيود الأمان. استخدمه للتشخيص فقط.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _schemaController,
                            decoration: InputDecoration(
                              labelText: 'Schema',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tableController,
                            decoration: InputDecoration(
                              labelText: 'جدول الاختبار',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _timeoutController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'مهلة الاتصال بالثواني',
                        prefixIcon: const Icon(Icons.timer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // بطاقة خيارات متقدمة
              _buildInfoCard(
                title: 'خيارات متقدمة',
                icon: Icons.settings,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _useHttpsOnly,
                      onChanged: (value) {
                        setState(() => _useHttpsOnly = value);
                      },
                      title: const Text('السماح فقط بروابط HTTPS'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      value: _autoRetry,
                      onChanged: (value) {
                        setState(() => _autoRetry = value);
                      },
                      title: const Text('إعادة المحاولة تلقائياً عند الفشل'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // أزرار التشخيص والإجراءات
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testConnection,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      label: const Text('اختبار الاتصال'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('حفظ الإعدادات'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // أزرار مساعدة
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testPing,
                      icon: const Icon(Icons.network_ping),
                      label: const Text('اختبار Ping'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testDns,
                      icon: const Icon(Icons.dns),
                      label: const Text('اختبار DNS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearCache,
                      icon: const Icon(Icons.cleaning_services),
                      label: const Text('مسح الكاش'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // بطاقة نتيجة الاختبار
              Card(
                color: _statusColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _statusColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_statusIcon, color: _statusColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _connectionStatus,
                              style: TextStyle(
                                color: _statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_connectionDetails.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _connectionDetails,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // بطاقة معلومات متقدمة (قابلة للطي)
              ExpansionTile(
                title: const Text('معلومات متقدمة'),
                leading: const Icon(Icons.info_outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                children: [
                  _buildInfoCard(
                    title: 'حالة الشبكة والصلاحيات',
                    icon: Icons.network_check,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusRow('الإنترنت', _hasInternet),
                        _buildStatusRow('DNS', _dnsWorking),
                        _buildStatusRow('API', _apiReachable),
                        _buildStatusRow('قاعدة البيانات', _dbAccessible),
                        if (_statusCode != null)
                          Text('HTTP Status: $_statusCode'),
                        if (_responseTime != null)
                          Text('زمن الاستجابة: $_responseTime ms'),
                        if (_pingResult.isNotEmpty) Text(_pingResult),
                        if (_dnsResult.isNotEmpty) Text(_dnsResult),
                        const Divider(height: 24),
                        ..._permissionResults.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $item'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_connectionLogs.isNotEmpty)
                    _buildInfoCard(
                      title: 'سجل العمليات',
                      icon: Icons.history,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _connectionLogs
                            .map(
                              (log) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('• $log'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:'),
          ),
          Icon(
            status ? Icons.check_circle : Icons.error,
            color: status ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(status ? 'يعمل' : 'لا يعمل'),
        ],
      ),
    );
  }
}