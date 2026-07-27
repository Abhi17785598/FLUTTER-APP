import 'package:equatable/equatable.dart';

class ProfileModel extends Equatable {
  final String id; // user_id (uuid)
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final String? userType; // e.g., "buyer", "seller", "agent"
  final String? userRole; // matches app_role enum
  final String? companyName;
  final String? bio;
  final String? workCity;
  final String? reraNumber;
  final String? verificationStatus; // enum: pending, verified, rejected
  final bool isOnline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.phone,
    this.userType,
    this.userRole,
    this.companyName,
    this.bio,
    this.workCity,
    this.reraNumber,
    this.verificationStatus,
    required this.isOnline,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory for Supabase row (Map<String, dynamic>)
  factory ProfileModel.fromSupabase(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      userType: json['user_type'] as String?,
      userRole: json['user_role'] as String?,
      companyName: json['company_name'] as String?,
      bio: json['bio'] as String?,
      workCity: json['work_city'] as String?,
      reraNumber: json['rera_number'] as String?,
      verificationStatus: json['verification_status'] as String?,
      isOnline: (json['is_online'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'email': email,
      'phone': phone,
      'user_type': userType,
      'user_role': userRole,
      'company_name': companyName,
      'bio': bio,
      'work_city': workCity,
      'rera_number': reraNumber,
      'verification_status': verificationStatus,
      'is_online': isOnline,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        avatarUrl,
        email,
        phone,
        userType,
        userRole,
        companyName,
        bio,
        workCity,
        reraNumber,
        verificationStatus,
        isOnline,
        createdAt,
        updatedAt,
      ];
}
