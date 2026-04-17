import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'customer';
  bool _offlineMode = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'الرجاء إدخال رقم الموبايل';
    if (!value.startsWith('7')) return 'يجب أن يبدأ الرقم بـ 7';
    if (value.length != 9) return 'يجب أن يتكون الرقم من 9 أرقام';
    return null;
  }

  Future<void> _handleLogin() async {
    if (_validatePhone(_phoneController.text.trim()) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم هاتف غير صالح')));
      return;
    }
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال كلمة المرور')));
      return;
    }
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      offlineMode: _offlineMode,
      role: _selectedRole,
      rememberMe: _rememberMe,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      final error = ref.read(authProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _forgotPassword() async {
    final phone = _phoneController.text.trim();
    if (_validatePhone(phone) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم هاتف غير صالح')));
      return;
    }
    await ref.read(authProvider.notifier).requestPasswordReset(phone);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب استعادة كلمة المرور')));
  }

  Future<void> _enableBiometric() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل البيانات أولاً')));
      return;
    }
    final success = await ref.read(authProvider.notifier).enableBiometric(_phoneController.text.trim(), _passwordController.text);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'تم تفعيل البصمة' : 'فشل تفعيل البصمة')));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text('مرحباً بكم في', style: TextStyle(fontSize: 24, color: Color(0xFFDCC86E))),
                const Text('محلات بن عبيد التجارية', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFDCC86E))),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(child: _buildRoleButton('delivery', 'وكيل', Icons.delivery_dining)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRoleButton('customer', 'عميل', Icons.person_outline)),
                  ],
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'رقم الموبايل',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Padding(padding: EdgeInsets.all(14), child: Text('7', style: TextStyle(color: Color(0xFFDCC86E), fontSize: 18))),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: const TextStyle(color: Colors.white70),
                    suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!), activeColor: const Color(0xFFFFD700)),
                    const Text('تذكرني', style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    TextButton(onPressed: _enableBiometric, child: const Text('تفعيل البصمة', style: TextStyle(color: Color(0xFFDCC86E)))),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: _forgotPassword, child: const Text('هل نسيت كلمة السر؟', style: TextStyle(color: Colors.white30))),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF0F3BBF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFDCC86E)))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () => context.push('/register'), child: const Text('لاتمتلك حساب؟ إنشاء حساب', style: TextStyle(color: Color(0xFFDCC86E)))),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFF1E3355), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF0F3BBF))),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(value: _offlineMode, onChanged: (v) => setState(() => _offlineMode = v!), activeColor: const Color(0xFFFFD700)),
                          const Text('دخول بدون نت', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(String role, String title, IconData icon) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF0F3BBF) : const Color(0xFF192537), borderRadius: BorderRadius.circular(18), border: Border.all(color: isSelected ? const Color(0xFFDCC86E) : Colors.transparent)),
        child: Column(children: [Icon(icon, size: 48, color: isSelected ? const Color(0xFFFFD700) : const Color(0xFFDCC86E)), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white, fontSize: 18))]),
      ),
    );
  }
}
