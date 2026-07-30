import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the deployed `send-otp` Supabase Edge Function.
///
/// Never creates, edits or redeploys a function — this only calls the one
/// already deployed for the shared backend (same function the website uses).
class EdgeFunctionsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// A function that returns HTTP 200 with `{ error: '...' }` is still a
  /// failure — surface the server's own message rather than a generic one.
  Future<Map<String, dynamic>> _invoke(
    String function, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _supabase.functions.invoke(function, body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw data['error'].toString();
      }
      return (data as Map<String, dynamic>?) ?? const <String, dynamic>{};
    } on FunctionException catch (e) {
      final message = e.details is Map ? e.details['error'] : null;
      throw message?.toString() ??
          'Could not reach the server. Please try again.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'A network error occurred. Please try again.';
    }
  }

  /// `phoneNumber` must already be E.164 (e.g. `+919876543210`) —
  /// see `Validators.toE164`.
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) =>
      _invoke('send-otp', body: {'action': 'send', 'phoneNumber': phoneNumber});

  /// `channel: 'voice'` asks MSG91 for a voice call retry instead of SMS.
  Future<Map<String, dynamic>> resendOtp(
    String phoneNumber, {
    String channel = 'text',
  }) => _invoke(
    'send-otp',
    body: {'action': 'resend', 'phoneNumber': phoneNumber, 'channel': channel},
  );

  /// Verifies the OTP. Does **not** return a session — see
  /// `AuthService.verifyOtp` for the magic-link exchange that does.
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? name,
  }) => _invoke(
    'send-otp',
    body: {
      'action': 'verify',
      'phoneNumber': phoneNumber,
      'otp': otp,
      if (name != null && name.isNotEmpty) 'name': name,
    },
  );
}
