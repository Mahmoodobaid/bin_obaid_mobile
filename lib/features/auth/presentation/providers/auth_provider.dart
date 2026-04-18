import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../models/user_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/backup_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

class AuthState {
  final bool isLoading;
  final String? error;
  final UserModel? currentUser;
  final bool isOfflineMode;

  const AuthState({this.isLoading = false, this.error, this.currentUser, this.isOfflineMode = false});

  AuthState copyWith({bool? isLoading, String? error, UserModel? currentUser, bool? isOfflineMode}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentUser: currentUser ?? this.currentUser,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
    );
  }

  bool get isAuthenticated => currentUser != null || isOfflineMode;
  bool get isAdmin => currentUser?.role == 'admin';
  bool get isDelivery => currentUser?.role == 'delivery';
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthNotifier(this.ref) : super(const AuthState()) {
    _initDefaultAdmin();
    _tryAutoLogin();
  }

  Future<void> _initDefaultAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('admin_phone')) {
      await prefs.setString('admin_phone', '770491653');
      await prefs.setString('admin_password', '770491653mall');
      await prefs.setString('admin_name', 'محمود عبيد');
      await prefs.setString('admin_role', 'admin');
    }
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('saved_phone');
    final savedPassword = prefs.getString('saved_password');
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    if (savedPhone != null && savedPassword != null) {
      if (biometricEnabled) {
        final canCheck = await _localAuth.canCheckBiometrics;
        if (canCheck) {
          final didAuthenticate = await _localAuth.authenticate(localizedReason: 'استخدم بصمتك لتسجيل الدخول');
          if (didAuthenticate) {
            await login(phone: savedPhone, password: savedPassword, offlineMode: false, role: 'customer');
          }
        }
      } else {
        await login(phone: savedPhone, password: savedPassword, offlineMode: false, role: 'customer');
      }
    }
  }

  Future<void> login({
    required String phone,
    required String password,
    required bool offlineMode,
    required String role,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    if (offlineMode) {
      final localUser = UserModel(
        id: 'local_$phone',
        phone: phone,
        fullName: 'مستخدم محلي',
        role: role,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(isLoading: false, currentUser: localUser, isOfflineMode: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final adminPhone = prefs.getString('admin_phone') ?? '770491653';
    final adminPassword = prefs.getString('admin_password') ?? '770491653mall';
    final adminName = prefs.getString('admin_name') ?? 'محمود عبيد';

    if (phone == adminPhone && password == adminPassword) {
      final adminUser = UserModel(
        id: 'admin_default',
        phone: adminPhone,
        fullName: adminName,
        role: 'admin',
        createdAt: DateTime.now(),
      );
      state = state.copyWith(isLoading: false, currentUser: adminUser, isOfflineMode: false);
      if (rememberMe) {
        await prefs.setString('saved_phone', phone);
        await prefs.setString('saved_password', password);
      }
      return;
    }

    final api = ref.read(apiServiceProvider);
    final result = await api.loginWithPhone(phone, password);
    if (result == null) {
      state = state.copyWith(isLoading: false, error: 'بيانات الدخول غير صحيحة');
      return;
    }

    final user = UserModel.fromJson(result);
    state = state.copyWith(isLoading: false, currentUser: user, isOfflineMode: false);
    if (rememberMe) {
      await prefs.setString('saved_phone', phone);
      await prefs.setString('saved_password', password);
    }
  }

  Future<void> register({
    required String phone,
    required String fullName,
    required String occupation,
    required String address,
    String? imageBase64,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiServiceProvider);
      final success = await api.submitRegistrationRequest(
        phone: phone,
        fullName: fullName,
        occupation: occupation,
        address: address,
        imageBase64: imageBase64,
      );
      state = state.copyWith(isLoading: false);
      if (!success) state = state.copyWith(error: 'فشل إرسال الطلب، حاول مجدداً');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> requestPasswordReset(String phone) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.addPasswordResetRequest(phone);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> enableBiometric(String phone, String password) async {
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) return false;
    final didAuthenticate = await _localAuth.authenticate(localizedReason: 'تفعيل تسجيل الدخول بالبصمة');
    if (didAuthenticate) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_phone', phone);
      await prefs.setString('saved_password', password);
      await prefs.setBool('biometric_enabled', true);
      return true;
    }
    return false;
  }

  void logout() {
    state = const AuthState();
  }

  Future<void> logoutWithBackup() async {
    final current = state.currentUser;
    final role = current?.role ?? 'customer';
    await BackupService.createBackup(userRole: role);
    logout();
  }
}
