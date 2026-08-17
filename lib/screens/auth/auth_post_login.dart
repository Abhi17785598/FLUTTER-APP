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
    await _clearPendingUserType(await SharedPreferences.getInstance());
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

  // user_type is null — consult the type selected on the signup form, but
  // only if it was set for THIS account. 'pending_user_type' alone is not
  // enough: it survived sign-out and outlived the account (or even Supabase
  // project) it was written for, so a completely different Google account
  // reaching this same null-user_type state would otherwise inherit
  // whatever role somebody else picked in an earlier session — see
  // AccountTypeScreen's / AuthProvider.signUp's 'pending_user_type_uid'.
  final prefs = await SharedPreferences.getInstance();
  final pendingType = prefs.getString('pending_user_type');
  final pendingForUid = prefs.getString('pending_user_type_uid');

  if (pendingType == null || pendingForUid != userId) {
    if (pendingType != null) await _clearPendingUserType(prefs);
    // No pending type for this account: first-time Google/phone sign-in
    // with no chosen type yet.
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
    await _clearPendingUserType(prefs);
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

Future<void> _clearPendingUserType(SharedPreferences prefs) async {
  await prefs.remove('pending_user_type');
  await prefs.remove('pending_user_type_uid');
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
