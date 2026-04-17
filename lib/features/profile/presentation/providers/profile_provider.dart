import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) => ProfileNotifier(ref));

class ProfileState {
  final bool isLoading;
  final String? error;
  ProfileState({this.isLoading = false, this.error});
  ProfileState copyWith({bool? isLoading, String? error}) => ProfileState(isLoading: isLoading ?? this.isLoading, error: error);
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref ref;
  ProfileNotifier(this.ref) : super(ProfileState());

  Future<void> updateProfile({String? fullName, File? avatarFile}) async {
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiServiceProvider);
      // تحويل الصورة إلى Base64 إذا وجدت
      String? imageBase64;
      if (avatarFile != null) {
        final bytes = await avatarFile.readAsBytes();
        imageBase64 = 'data:image/jpeg;base64,${bytes}';
      }
      await api.updateUserProfile(fullName: fullName, avatarUrl: imageBase64);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> changePassword(String newPassword) async {
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.changePassword(newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
