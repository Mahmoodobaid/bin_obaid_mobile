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

  String _connectionStatus = 'لم يتم اختبار الاتصال بعد';
  String _connectionDetails = '';
  Color _statusColor = Colors.grey;
  IconData _statusIcon = Icons.info_outline;

  int? _statusCode;
  int? _responseTime;
  bool _hasInternet = false;
  bool _dnsWorking = false;
  bool _apiReachable = false;

  List<String> _permissionResults = [];
  List<String> _connectionLogs = [];

  // معلومات الجهاز والتطبيق
  String _deviceInfo = '';
  String _appInfo = '';

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

    await _checkInternetAvailability();

    if (mounted) setState(() {});
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

    setState(() {});
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

    final internetStatus = await Permission.internet.status;
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

  /// إنشاء تقرير نصي كامل بنسق منسق
  String _generateFullReport() {
    final buffer = StringBuffer();
    final now = DateTime.now();

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('📱 تقرير تشخيص الاتصال - بن عبيد التجارية');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('📅 التاريخ والوقت: ${now.toString()}');
    buffer.writeln('');
    buffer.writeln('📌 معلومات الجهاز والتطبيق:');
    buffer.writeln('   $deviceInfo');
    buffer.writeln('   $appInfo');
    buffer.writeln('');
    buffer.writeln('🌐 حالة الشبكة:');
    buffer.writeln('   الإنترنت: ${_hasInternet ? 'متصل' : 'غير متصل'}');
    buffer.writeln('   DNS: ${_dnsWorking ? 'يعمل' : 'لا يعمل'}');
    buffer.writeln('');
    buffer.writeln('🔧 إعدادات الخادم:');
    buffer.writeln('   الرابط: ${_urlController.text}');
    buffer.writeln('   المخطط (Schema): ${_schemaController.text}');
    buffer.writeln('   جدول الاختبار: ${_tableController.text}');
    buffer.writeln('   مهلة الاتصال: ${_timeoutController.text} ثانية');
    buffer.writeln('');
    buffer.writeln('🔑 تحليل المفتاح:');
    final key = _keyController.text.trim();
    final isServiceRole = key.contains('service_role');
    buffer.writeln('   نوع المفتاح: ${isServiceRole ? 'service_role (مدير)' : 'anon (عميل)'}');
    buffer.writeln('   طول المفتاح: ${key.length} حرفاً');
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

  /// نسخ التقرير الكامل إلى الحافظة
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
        setState(() {
          _connectionStatus = '✅ الاتصال ناجح';
          _connectionDetails = '''
الخادم يعمل بشكل طبيعي
الاستجابة: ${response.statusCode}
الوقت: ${_responseTime} ms
عدد السجلات المرجعة: ${(response.data as List).length}
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
    });
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
    List<Widget>? actions,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actions != null) ...actions,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الاتصال بقاعدة البيانات'),
          actions: [
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
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(
                title: 'إعدادات الخادم',
                icon: Icons.cloud,
                actions: [
                  const Spacer(),
                  IconButton(
                    onPressed: _copyKey,
                    icon: const Icon(Icons.copy),
                    tooltip: 'نسخ المفتاح',
                  ),
                ],
                child: Column(
                  children: [
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'رابط Supabase',
                        hintText: 'https://your-project.supabase.co',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
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
                        prefixIcon: const Icon(Icons.key),
                        border: const OutlineInputBorder(),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _schemaController,
                            decoration: const InputDecoration(
                              labelText: 'Schema',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tableController,
                            decoration: const InputDecoration(
                              labelText: 'جدول الاختبار',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _timeoutController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مهلة الاتصال بالثواني',
                        prefixIcon: Icon(Icons.timer),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'خيارات إضافية',
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
              const SizedBox(height: 16),
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: _statusColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _statusColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_statusIcon, color: _statusColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _connectionStatus,
                              style: TextStyle(
                                color: _statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_connectionDetails.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(_connectionDetails),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('معلومات متقدمة'),
                leading: const Icon(Icons.info_outline),
                children: [
                  _buildInfoCard(
                    title: 'حالة الشبكة والصلاحيات',
                    icon: Icons.network_check,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الإنترنت: ${_hasInternet ? 'متصل' : 'غير متصل'}'),
                        Text('DNS: ${_dnsWorking ? 'يعمل' : 'لا يعمل'}'),
                        Text('API: ${_apiReachable ? 'متاح' : 'غير متاح'}'),
                        if (_statusCode != null)
                          Text('HTTP Status: $_statusCode'),
                        if (_responseTime != null)
                          Text('زمن الاستجابة: $_responseTime ms'),
                        const SizedBox(height: 12),
                        ..._permissionResults.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
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
                                padding: const EdgeInsets.only(bottom: 6),
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
}