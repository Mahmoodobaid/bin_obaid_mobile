import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/user_model.dart';
import '../../../../services/api_service.dart';

final adminRequestProvider = StateNotifierProvider<AdminRequestNotifier, AdminRequestState>((ref) => AdminRequestNotifier(ref));

class AdminRequestState {
  final List<PendingUser> pendingUsers;
  final List<PasswordResetRequest> passwordResetRequests;
  final bool isLoading;
  AdminRequestState({this.pendingUsers = const [], this.passwordResetRequests = const [], this.isLoading = false});
  AdminRequestState copyWith({List<PendingUser>? pendingUsers, List<PasswordResetRequest>? passwordResetRequests, bool? isLoading}) =>
      AdminRequestState(pendingUsers: pendingUsers ?? this.pendingUsers, passwordResetRequests: passwordResetRequests ?? this.passwordResetRequests, isLoading: isLoading ?? this.isLoading);
}

class AdminRequestNotifier extends StateNotifier<AdminRequestState> {
  final Ref ref;
  AdminRequestNotifier(this.ref) : super(AdminRequestState());

  Future<void> loadRequests() async {
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiServiceProvider);
      final pending = await api.getPendingUsers();
      final resets = await api.getPasswordResetRequests();
      state = state.copyWith(
        pendingUsers: pending.map((e) => PendingUser.fromJson(e)).toList(),
        passwordResetRequests: resets.map((e) => PasswordResetRequest.fromJson(e)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> approveUser(String id, String phone, String name, String role) async {
    final api = ref.read(apiServiceProvider);
    await api.updatePendingUserStatus(id, 'approved');
    await api.createUserAccount(phone: phone, fullName: name, role: role, password: '123456');
    loadRequests();
  }

  Future<void> rejectUser(String id, String reason) async {
    final api = ref.read(apiServiceProvider);
    await api.updatePendingUserStatus(id, 'rejected', rejectReason: reason);
    loadRequests();
  }
}
