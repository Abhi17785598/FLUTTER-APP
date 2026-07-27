import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart'; 

/// Service responsible for reading and writing user profile data
/// to the `profiles` table in Supabase.
class ProfileService {
 final AuthService _authService = AuthService();

  /// Saves / updates a Builder profile for the currently authenticated user.
  ///
  /// Throws an [Exception] if the user is not authenticated or if the
  /// update operation fails for any reason.
  Future<void> saveBuilderProfile({
    required String companyName,
    required String email,
    required String mobile,
    required String city,
    required String state,
    required String officeAddress,
    required String pincode,
    required String reraNumber,
    required String yearsOfExperience,
    required String website,
    required String aboutCompany,
    required String username,
    required String avatarUrl,
  }) async {
    try {
      // ─── Get current authenticated user ──────────────────────────────
     final user = _authService.currentUser;

      if (user == null) {
        throw Exception('No authenticated user found. Please log in again.');
      }

      // ─── Build the payload for the profiles table ────────────────────
      final Map<String, dynamic> updateData = {
        'display_name': companyName,
        'company_name': companyName,
        'email': email,
        'phone': mobile,
        'mobile_number': mobile,
        'city': city,
        'work_city': city,
        'state': state,
        'office_address': officeAddress,
        'pincode': pincode,
        'rera_number': reraNumber,
      'years_of_experience':
    yearsOfExperience.trim().isEmpty
        ? null
        : int.tryParse(yearsOfExperience),
        'website': website,
        'website_url': website,
        'company_description': aboutCompany,
        'bio': aboutCompany,
        'username': username,
        'avatar_url': avatarUrl,
        'approval_status': 'pending',
        'profile_complete': true,
        'is_active': true,
        'user_type': 'builder',
      };

      // ─── Update the profiles table for this user ─────────────────────
      print('BUILDER DATA =====');
print(updateData);

    await _authService.updateProfileFields(
  user.id,
  updateData,
);

    } on PostgrestException catch (e) {
      throw Exception('Database error while saving builder profile: ${e.message}');
    } on AuthException catch (e) {
      throw Exception('Authentication error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while saving builder profile: $e');
    }
  }

  Future<void> saveBrokerProfile({
  required String fullName,
  required String reraNumber,
  required String licenseNumber,
  required String agencyName,
  required String yearsOfExperience,
  required String companyDescription,
  required String officeAddress,
  required String city,
  required String state,
  required String pincode,
  required String email,
  required String website,
  required String mobileNumber,
  required List<String> propertyTypes,
  required List<String> operatingCities,
}) async {
  final AuthService _authService = AuthService();
  final supabase = Supabase.instance.client;

  try {
    final user = _authService.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    // ─── Upsert into broker_profiles ──────────────────────────────────
    await supabase.from('broker_profiles').upsert(
      {
        'user_id': user.id,
        'full_name': fullName,
        'rera_number': reraNumber,
        'license_number': licenseNumber,
        'agency_name': agencyName,
      'years_of_experience':
    yearsOfExperience.trim().isEmpty
        ? null
        : int.tryParse(yearsOfExperience),
        'company_description': companyDescription,
        'office_address': officeAddress,
        'city': city,
        'state': state,
        'pincode': pincode,
        'email': email,
        'website': website,
        'mobile_number': mobileNumber,
        'property_types': propertyTypes,
        'operating_cities': operatingCities,
        'approval_status': 'pending',
      },
      onConflict: 'user_id',
    );

    // ─── Sync shared fields on the profiles table ─────────────────────
    await _authService.updateProfileFields(
      user.id,
      {
        'display_name': fullName,
        'company_name': agencyName,
        'phone': mobileNumber,
        'mobile_number': mobileNumber,
        'email': email,
        'city': city,
        'work_city': city,
        'state': state,
        'office_address': officeAddress,
        'pincode': pincode,
        'website': website,
        'website_url': website,
        'user_type': 'broker',
        'profile_complete': true,
        'approval_status': 'pending',
      },
    );
  } on PostgrestException catch (e) {
    throw Exception('Database error while saving broker profile: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Authentication error: ${e.message}');
  } catch (e) {
    throw Exception('Unexpected error while saving broker profile: $e');
  }
}

/// Saves / updates an Influencer profile for the currently authenticated
/// user. Influencer data is stored entirely on the `profiles` table
/// (no separate influencer_profiles table).
///
/// Throws an [Exception] if the user is not authenticated or if the
/// update operation fails.
Future<void> saveInfluencerProfile({
  required String fullName,
  required String email,
  required String mobileNumber,
  required String city,
  required String state,
  required String bio,
  required String instagramUsername,
  required String youtubeChannelLink,
  required List<String> contentTypes,
  required List<String> preferredPromotionTypes,
  required List<String> portfolioLinks,
  required List<String> previousBrandCollaborations,
}) async {
  final AuthService _authService = AuthService();

  try {
    final user = _authService.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    // ─── Update profiles table with influencer data ───────────────────
    await _authService.updateProfileFields(
      user.id,
      {
        'display_name': fullName,
        'email': email,
        'phone': mobileNumber,
        'mobile_number': mobileNumber,
        'city': city,
        'state': state,
        'bio': bio,
        'user_type': 'influencer',
        'profile_complete': true,
        'approval_status': 'pending',
        'social_media': {
          'instagram_username': instagramUsername,
          'youtube_channel_link': youtubeChannelLink,
          'content_types': contentTypes,
          'preferred_promotion_types': preferredPromotionTypes,
          'portfolio_links': portfolioLinks,
          'previous_brand_collaborations': previousBrandCollaborations,
        },
      },
    );
  } on PostgrestException catch (e) {
    throw Exception('Database error while saving influencer profile: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Authentication error: ${e.message}');
  } catch (e) {
    throw Exception('Unexpected error while saving influencer profile: $e');
  }
}
}