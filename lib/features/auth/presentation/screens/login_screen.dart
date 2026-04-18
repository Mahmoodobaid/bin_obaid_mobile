import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController(), _pass = TextEditingController();
  String _role = 'customer';
  bool _offline = false, _remember = false, _loading = false, _obscure = true;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _tryBiometricLogin();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('saved_phone');
    final savedPass = prefs.getString('saved_password');
    final remember = prefs.getBool('remember_me') ?? false;
    if (remember && savedPhone != null && savedPass != null) {
      _phone.text = savedPhone;
      _pass.text = savedPass;
      _remember = true;
    }
  }

  Future<void> _tryBiometricLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final bioEnabled = prefs.getBool('biometric_enabled') ?? false;
    if (!bioEnabled) return;
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) return;
    final didAuth = await _localAuth.authenticate(localizedReason: 'تسجيل الدخول بالبصمة');
    if (didAuth) {
      final savedPhone = prefs.getString('saved_phone');
      final savedPass = prefs.getString('saved_password');
      if (savedPhone != null && savedPass != null) {
        _phone.text = savedPhone;
        _pass.text = savedPass;
        await _doLogin();
      }
    }
  }

  Future<void> _enableBiometric() async {
    if (_phone.text.isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل البيانات أولاً')));
      return;
    }
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الجهاز لا يدعم البصمة')));
      return;
    }
    final didAuth = await _localAuth.authenticate(localizedReason: 'تفعيل تسجيل الدخول بالبصمة');
    if (didAuth) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_phone', _phone.text.trim());
      await prefs.setString('saved_password', _pass.text);
      await prefs.setBool('biometric_enabled', true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل البصمة بنجاح')));
    }
  }

  Future<void> _doLogin() async {
    if (_phone.text.trim().isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل البيانات')));
      return;
    }
    setState(() => _loading = true);
    if (_remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_phone', _phone.text.trim());
      await prefs.setString('saved_password', _pass.text);
      await prefs.setBool('remember_me', true);
    }
    await ref.read(authProvider.notifier).login(
      phone: _phone.text.trim(),
      password: _pass.text,
      offlineMode: _offline,
      role: _role,
      rememberMe: _remember,
    );
    if (mounted) {
      setState(() => _loading = false);
      if (ref.read(authProvider).error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(authProvider).error!)));
      } else if (ref.read(authProvider).currentUser != null) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(height: 20),
                const Text('مرحباً بكم في', style: TextStyle(fontSize: 24, color: Color(0xFFDCC86E))),
                const Text('محلات بن عبيد التجارية', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFDCC86E))),
                const SizedBox(height: 40),
                Row(children: [
                  Expanded(child: _roleBtn('delivery', 'وكيل', Icons.delivery_dining)),
                  const SizedBox(width: 16),
                  Expanded(child: _roleBtn('customer', 'عميل', Icons.person_outline)),
                ]),
                const SizedBox(height: 30),
                TextField(controller: _phone, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'رقم الموبايل', prefixText: '7 ', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 20),
                TextField(controller: _pass, obscureText: _obscure, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'كلمة المرور', labelStyle: const TextStyle(color: Colors.white70), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white54), onPressed: () => setState(() => _obscure = !_obscure)))),
                Row(children: [
                  Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v!), activeColor: const Color(0xFFFFD700)),
                  const Text('تذكرني', style: TextStyle(color: Colors.white)),
                  const Spacer(),
                  TextButton(onPressed: _enableBiometric, child: const Text('تفعيل البصمة', style: TextStyle(color: Color(0xFFDCC86E)))),
                ]),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _doLogin,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF0F3BBF)),
                  child: _loading ? const CircularProgressIndicator() : const Text('تسجيل الدخول'),
                ),
                Row(children: [
                  Checkbox(value: _offline, onChanged: (v) => setState(() => _offline = v!), activeColor: const Color(0xFFFFD700)),
                  const Text('دخول بدون نت', style: TextStyle(color: Colors.white)),
                  const Spacer(),
                  TextButton(onPressed: () => context.push('/register'), child: const Text('إنشاء حساب', style: TextStyle(color: Color(0xFFDCC86E)))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleBtn(String role, String title, IconData icon) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F3BBF) : const Color(0xFF192537),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? const Color(0xFFDCC86E) : Colors.transparent),
        ),
        child: Column(children: [Icon(icon, color: const Color(0xFFDCC86E)), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white))]),
      ),
    );
  }
}
