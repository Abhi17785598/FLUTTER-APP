import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_screen.dart';
import 'account_type_screen.dart';

/// Decides where a just-authenticated user goes, shared by every entry point
/// that can complete a sign-in (email login/signup, phone OTP verify):
///   - profile_complete == true   → HomeScreen
///   - user_type already set      → resume that registration screen
///   - user_type null, pending = individual → write profile, go home
///   - user_type null, pending = business   → open that registration screen
///   - user_type null, no pending type      → AccountTypeScreen (first-time
///     Google/phone sign-in that hasn't chosen an account type yet)
Future<void> routeAfterAuth(BuildContext context, String userId) async {
  final profile = await Supabase.instance.client
      .from('profiles')
      .select('user_type, profile_complete')
      .eq('user_id', userId)
      .maybeSingle();

  final isComplete = profile?['profile_complete'] == true;
  final dbUserType = profile?['user_type'] as String?;

  if (isComplete) {
    (await SharedPreferences.getInstance()).remove('pending_user_type');
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
    return;
  }

  // user_type already written (e.g. returning user mid-registration).
  if (dbUserType != null) {
    _pushRegistrationRoute(context, dbUserType);
    return;
  }

  // user_type is null — consult the type selected on the signup form.
  final prefs = await SharedPreferences.getInstance();
  final pendingType = prefs.getString('pending_user_type');

  if (pendingType == null) {
    // No pending type: first-time Google/phone sign-in with no chosen type yet.
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AccountTypeScreen(userId: userId)),
      );
    }
    return;
  }

  if (pendingType == 'individual') {
    await Supabase.instance.client
        .from('profiles')
        .update({'user_type': 'individual', 'profile_complete': true})
        .eq('user_id', userId);
    await prefs.remove('pending_user_type');
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  } else {
    _pushRegistrationRoute(context, pendingType);
  }
}

void _pushRegistrationRoute(BuildContext context, String userType) {
  if (!context.mounted) return;
  if (userType == 'builder') {
    Navigator.pushReplacementNamed(context, '/builder-profile');
  } else if (userType == 'broker') {
    Navigator.pushReplacementNamed(context, '/broker-profile');
  } else if (userType == 'influencer') {
    Navigator.pushReplacementNamed(context, '/influencer-profile');
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
