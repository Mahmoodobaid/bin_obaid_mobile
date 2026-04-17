class UserModel {
  final String id, phone, email, fullName, role;
  final bool isActive, biometricEnabled;
  final String? avatarUrl;
  final DateTime createdAt;
  UserModel({required this.id, required this.phone, this.email='', required this.fullName, required this.role, this.isActive=true, this.biometricEnabled=false, this.avatarUrl, required this.createdAt});
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(id: json['id'], phone: json['phone'], email: json['email']??'', fullName: json['full_name'], role: json['role'], isActive: json['is_active']??true, biometricEnabled: json['biometric_enabled']??false, avatarUrl: json['avatar_url'], createdAt: DateTime.parse(json['created_at']));
  Map<String, dynamic> toJson() => {'id':id, 'phone':phone, 'email':email, 'full_name':fullName, 'role':role, 'is_active':isActive, 'biometric_enabled':biometricEnabled, 'avatar_url':avatarUrl, 'created_at':createdAt.toIso8601String()};
  UserModel copyWith({String? fullName, String? avatarUrl}) => UserModel(id: id, phone: phone, email: email, fullName: fullName??this.fullName, role: role, isActive: isActive, biometricEnabled: biometricEnabled, avatarUrl: avatarUrl??this.avatarUrl, createdAt: createdAt);
}
class PendingUser { final String id, phone, fullName, occupation, address; final String? imageUrl; final DateTime createdAt; PendingUser({required this.id, required this.phone, required this.fullName, required this.occupation, required this.address, this.imageUrl, required this.createdAt}); factory PendingUser.fromJson(Map<String, dynamic> json) => PendingUser(id: json['id'].toString(), phone: json['phone'], fullName: json['full_name'], occupation: json['occupation']??'', address: json['address']??'', imageUrl: json['image_url'], createdAt: DateTime.parse(json['created_at'])); }
class PasswordResetRequest { final String id, phone, status; final DateTime createdAt; PasswordResetRequest({required this.id, required this.phone, required this.status, required this.createdAt}); factory PasswordResetRequest.fromJson(Map<String, dynamic> json) => PasswordResetRequest(id: json['id'].toString(), phone: json['phone'], status: json['status']??'pending', createdAt: DateTime.parse(json['created_at'])); }
