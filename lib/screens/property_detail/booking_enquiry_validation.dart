// screens/property_detail/booking_enquiry_validation.dart
//
// Pure validation/formatting helpers for the Schedule Visit and Enquiry
// bottom sheets in `property_detail_screen.dart` — split out so the exact
// portal-equivalent rules can be unit tested without building the whole
// (network-loading) screen.
library;

/// `BookVisitModal.tsx:112-130`'s name/phone validators, transcribed exactly.
class VisitFormValidation {
  const VisitFormValidation._();

  static String? nameError(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name is required';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) {
      return 'Name should only contain alphabets';
    }
    return null;
  }

  static String? phoneError(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return 'Phone number required';
    if (trimmed.length < 10) return 'Enter valid 10 digit mobile number';
    return null;
  }

  /// `BookVisitModal.tsx:344-350`: a slot is disabled once its literal
  /// leading number is <= the current 24-hour hour, and only when [date] is
  /// today. Transcribed exactly, quirks included — e.g. "01:00" (meant as
  /// 1 PM) only disables in the 00:xx/01:xx hour of the following morning,
  /// not in the afternoon it actually represents.
  static bool isSlotDisabled(String time, DateTime date, DateTime now) {
    final bool isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (!isToday) return false;
    final int slotHour = int.parse(time.split(':').first);
    return slotHour <= now.hour;
  }
}

/// Maps a thrown booking/enquiry-submission error to display text.
///
/// [StateError] is raised by `VisitBookingService`/`PropertyInquiryService`
/// themselves with a message already meant for display (e.g. "Sign in to
/// book a visit."); anything else (a `PostgrestException`, a network error)
/// surfaces its own message so the failure is truthful rather than generic,
/// falling back to a plain retry prompt only when the error carries no
/// usable text.
String describeSubmitError(Object error, String actionFailedPrefix) {
  if (error is StateError) return error.message;
  final String text = error.toString();
  return text.isEmpty
      ? '$actionFailedPrefix. Please try again.'
      : '$actionFailedPrefix: $text';
}
