// Direct port of propcid/src/lib/validation/requiredFields.ts.
//
// final-architecture-review Q6 requires the validator INTERNALS be ported
// verbatim rather than approximated: "A subtly different isBlank or phone regex
// will pass/fail different inputs than the Web, breaking step-gating parity."
//
// T0 ships only the engine. The rule table itself (propertyListingRules.ts) is
// T2 and is deliberately not started here.

/// Regexes copied character-for-character from `PATTERN` (requiredFields.ts:99).
class ListingPattern {
  ListingPattern._();

  static final RegExp email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp pincode = RegExp(r'^\d{6}$');
  static final RegExp phone = RegExp(r'^\+?[\d\s-]{8,15}$');

  /// Letters, digits, `/` and `-` only, 8 to 60 characters — not a React
  /// port. State RERA formats vary too widely (Maharashtra's `P51800012345`,
  /// Gujarat's long slash-segmented ids, Haryana's, Karnataka's...) to
  /// pattern-match beyond character set and length, so no state-specific
  /// format is enforced on purpose.
  static final RegExp rera = RegExp(r'^[A-Za-z0-9/-]{8,60}$');
}

/// Mirrors JavaScript's `Number(String)` coercion, which Dart does NOT share.
///
/// This matters: `Number('')` is **0** in JS, while `double.tryParse('')` is
/// null in Dart. React's [positiveNumber] strips non-numeric characters first,
/// so an input of `'abc'` becomes `''` -> 0 -> "must be greater than 0", NOT
/// "must be a number". Using tryParse directly would emit the wrong message and
/// take a different branch than the web for the same input.
///
/// Returns null where JS yields NaN.
double? _jsNumber(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return 0; // Number('') === 0
  return double.tryParse(t); // null == NaN
}

/// Strips everything except digits, dot and minus — React's
/// `String(value).replace(/[^\d.-]/g, '')`.
String _stripToNumeric(Object? value) =>
    value.toString().replaceAll(RegExp(r'[^\d.-]'), '');

/// A value counts as "provided" when it is a non-empty string, a finite number,
/// a non-empty collection, or a boolean.
///
/// Verbatim from `isBlank` (requiredFields.ts:42). The boolean case is the one
/// most easily got wrong: **`false` is a deliberate answer, not a blank**, so an
/// unchecked required checkbox passes this check.
bool isBlank(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim() == '';
  if (value is num) return value.isNaN;
  if (value is bool) return false; // false is an answer
  if (value is List) return value.isEmpty;
  if (value is Set) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}

/// Rejects "0", "-5" and "abc" for amount/count inputs.
/// Verbatim from `positiveNumber` (requiredFields.ts:106).
String? Function(Object?) positiveNumber(String label) {
  return (Object? value) {
    final double? n = _jsNumber(_stripToNumeric(value));
    if (n == null) return '$label must be a number.';
    if (n <= 0) return '$label must be greater than 0.';
    return null;
  };
}

/// Same as [positiveNumber] but with a caller-supplied floor instead of a
/// bare "greater than 0" — not a React port.
String? Function(Object?) minNumber(num min, String label) {
  return (Object? value) {
    final double? n = _jsNumber(_stripToNumeric(value));
    if (n == null) return '$label must be a number.';
    if (n < min) return '$label must be at least $min.';
    return null;
  };
}

/// Same as [positiveNumber] but allows 0 (floor numbers, balcony counts...).
/// Verbatim from `nonNegativeNumber` (requiredFields.ts:116).
String? Function(Object?) nonNegativeNumber(String label) {
  return (Object? value) {
    final double? n = _jsNumber(_stripToNumeric(value));
    if (n == null) return '$label must be a number.';
    if (n < 0) return '$label cannot be negative.';
    return null;
  };
}

/// NOTE: React does NOT trim before testing email, but DOES for pincode/phone.
/// Preserved exactly, so a trailing space fails email here as it does on web.
String? validEmail(Object? value) =>
    ListingPattern.email.hasMatch(value.toString())
    ? null
    : 'Enter a valid email address.';

String? validPincode(Object? value) =>
    ListingPattern.pincode.hasMatch(value.toString().trim())
    ? null
    : 'Pincode must be 6 digits.';

String? validPhone(Object? value) =>
    ListingPattern.phone.hasMatch(value.toString().trim())
    ? null
    : 'Enter a valid contact number.';

String? validRera(Object? value) =>
    ListingPattern.rera.hasMatch(value.toString().trim())
    ? null
    : 'RERA number must be 8-60 characters, using only letters, numbers, '
          'slashes and hyphens.';

String? Function(Object?) minLength(int n, String label) {
  return (Object? value) => value.toString().trim().length < n
      ? '$label must be at least $n characters.'
      : null;
}

/// Enforces a minimum word count on long-form text (project/property
/// descriptions) — not part of the React port, added on explicit request so a
/// description can't be a single word.
String? Function(Object?) minWordCount(int n, String label) {
  return (Object? value) {
    final words = value.toString().trim().split(RegExp(r'\s+'));
    final count = words.where((w) => w.isNotEmpty).length;
    return count < n
        ? '$label must be at least $n words (currently $count).'
        : null;
  };
}

/// Compact one-line summary for a toast: "Area, Bedrooms, Bathrooms and 4 more".
/// Mirrors `summariseIssues` (requiredFields.ts:81).
String summariseIssues(List<String> labels, {int max = 4}) {
  if (labels.isEmpty) return '';
  if (labels.length <= max) {
    if (labels.length == 1) return labels.first;
    return '${labels.sublist(0, labels.length - 1).join(', ')} and ${labels.last}';
  }
  return '${labels.sublist(0, max).join(', ')} and ${labels.length - max} more';
}
