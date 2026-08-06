// models/property_detail_bundle.dart
import 'property_model.dart';

/// Standalone, fully-nullable owner-profile view model for the property
/// detail screen.
///
/// Deliberately its own type rather than a shared profile model: the detail
/// screen selects a narrow `display_name, avatar_url, user_type[, phone],
/// social_media` column list, with phone included only when the caller is
/// signed in, matching the website's PII-aware query. A model requiring
/// non-nullable id/createdAt/updatedAt cannot represent that row.
///
/// (Phase 11 note: this previously referenced `ProfileModel`, an orphaned
/// never-imported file deleted in that phase.)
class PropertyOwnerProfile {
  final String? displayName;
  final String? avatarUrl;
  final String? userType;
  final String? companyName;
  final String? phone;
  final Map<String, dynamic>? socialMedia;

  const PropertyOwnerProfile({
    this.displayName,
    this.avatarUrl,
    this.userType,
    this.companyName,
    this.phone,
    this.socialMedia,
  });

  factory PropertyOwnerProfile.fromSupabase(Map<String, dynamic> json) {
    return PropertyOwnerProfile(
      displayName: json['display_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      userType: json['user_type']?.toString(),
      companyName: json['company_name']?.toString(),
      phone: json['phone']?.toString(),
      socialMedia: json['social_media'] as Map<String, dynamic>?,
    );
  }
}

/// Return type of PropertyService.getPropertyDetail — the property row plus
/// its owner's profile, resolved via the same 3-query shape PropertyDetails
/// .tsx uses on the website.
class PropertyDetailBundle {
  final PropertyModel property;
  final PropertyOwnerProfile? ownerProfile;

  const PropertyDetailBundle({
    required this.property,
    this.ownerProfile,
  });
}
