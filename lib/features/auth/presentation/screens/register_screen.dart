import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../../../../services/api_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _jobController = TextEditingController();
  final _addressController = TextEditingController();
  File? _imageFile;
  String? _imageBase64;
  bool _isCheckingPhone = false;
  bool _phoneExists = false;
  String? _phoneCheckMessage;
  bool _isLoading = false;
  static const List<String> _jobs = ['كهربائي', 'سباك', 'مهندس', 'مقاول', 'معلم ديكور', 'تاجر', 'أخرى'];

  @override
  void dispose() {
    _phoneController.dispose(); _nameController.dispose(); _jobController.dispose(); _addressController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) return 'مطلوب';
    if (!v.startsWith('7')) return 'يبدأ بـ7';
    if (v.length != 9) return '9 أرقام';
    if (_phoneExists) return 'الرقم مسجل';
    return null;
  }

  Future<void> _checkPhone() async {
    final p = _phoneController.text.trim();
    if (p.length != 9 || !p.startsWith('7')) { setState(() { _phoneExists = false; _phoneCheckMessage = null; }); return; }
    setState(() => _isCheckingPhone = true);
    final api = ref.read(apiServiceProvider);
    final exists = await api.checkPhoneExists(p) || await api.checkPendingPhoneExists(p);
    setState(() { _phoneExists = exists; _phoneCheckMessage = exists ? 'الرقم مسجل' : null; _isCheckingPhone = false; });
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p != null) { final b = await p.readAsBytes(); setState(() { _imageFile = File(p.path); _imageBase64 = base64Encode(b); }); }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _phoneExists) return;
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).register(phone: _phoneController.text.trim(), fullName: _nameController.text.trim(), occupation: _jobController.text.trim(), address: _addressController.text.trim(), imageBase64: _imageBase64);
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإرسال'))); context.pop(); }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إنشاء حساب جديد')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(radius: 60, backgroundColor: Colors.grey.shade200, backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null, child: _imageFile == null ? const Icon(Icons.add_a_photo, size: 40) : null),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                  decoration: const InputDecoration(labelText: 'رقم الموبايل', prefixText: '7 ', border: OutlineInputBorder()),
                  validator: _validatePhone,
                  onChanged: (_) => _checkPhone(),
                ),
                if (_isCheckingPhone) const CircularProgressIndicator(),
                if (_phoneCheckMessage != null) Text(_phoneCheckMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (v) => v.text.isEmpty ? [] : _jobs.where((j) => j.contains(v.text)).toList(),
                  onSelected: (v) => _jobController.text = v,
                  fieldViewBuilder: (c, ctrl, f, _) => TextFormField(controller: ctrl, focusNode: f, decoration: const InputDecoration(labelText: 'مهنة العميل', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null),
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'عنوان العميل (اختياري)', border: OutlineInputBorder())),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('إنشاء حساب', style: TextStyle(fontSize: 18)),
                ),
                TextButton(onPressed: () => context.pop(), child: const Text('لديك حساب بالفعل؟ تسجيل الدخول')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
