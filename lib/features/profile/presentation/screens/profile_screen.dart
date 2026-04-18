import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/user_model.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isEditing = false;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).currentUser;
    if (user != null) _nameController.text = user.fullName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  void _saveProfile() {
    ref.read(profileProvider.notifier).updateProfile(fullName: _nameController.text);
    setState(() => _isEditing = false);
  }

  void _changePassword() {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال كلمتي المرور')));
      return;
    }
    ref.read(profileProvider.notifier).changePassword(_newPasswordController.text);
    _currentPasswordController.clear();
    _newPasswordController.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    if (user == null) return const Center(child: Text('يرجى تسجيل الدخول'));

    ImageProvider? backgroundImage;
    if (_avatarFile != null) {
      backgroundImage = FileImage(_avatarFile!);
    } else if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(user.avatarUrl!);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الملف الشخصي'),
          actions: [
            if (!_isEditing)
              IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true))
            else
              IconButton(icon: const Icon(Icons.check), onPressed: _saveProfile),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isEditing ? _pickAvatar : null,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: backgroundImage,
                  child: backgroundImage == null ? const Icon(Icons.person, size: 60) : null,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                enabled: _isEditing,
                decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(user.phone),
                subtitle: const Text('رقم الهاتف'),
              ),
              ListTile(
                leading: const Icon(Icons.badge),
                title: Text(user.role == 'admin' ? 'مدير' : user.role == 'delivery' ? 'مندوب' : 'عميل'),
                subtitle: const Text('نوع الحساب'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('تغيير كلمة المرور'),
                onTap: () => _showChangePasswordDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('الإعدادات'),
                onTap: () => context.push('/settings'),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _currentPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
            const SizedBox(height: 12),
            TextField(controller: _newPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: _changePassword, child: const Text('حفظ')),
        ],
      ),
    );
  }
}
