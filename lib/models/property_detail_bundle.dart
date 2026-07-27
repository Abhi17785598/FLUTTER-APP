// models/property_detail_bundle.dart
import 'property_model.dart';

/// Standalone, fully-nullable owner-profile view model for the property
/// detail screen. Deliberately NOT ProfileModel — that model's fromSupabase
/// requires non-nullable id/createdAt/updatedAt and throws against the
/// narrower `display_name, avatar_url, user_type[, phone], social_media`
/// column list the detail screen actually selects (phone is only included
/// when the caller is signed in, matching the website's PII-aware query).
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
