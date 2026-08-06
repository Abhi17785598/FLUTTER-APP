// T0 validator-parity guard.
//
// final-architecture-review Q6: the validator internals must be ported verbatim,
// not approximated — "A subtly different isBlank or phone regex will pass/fail
// different inputs than the Web, breaking step-gating parity."
//
// Each expectation below states what the JS does, so a future edit that "fixes"
// an apparent oddity (empty string coercing to 0, `false` counting as answered)
// fails loudly instead of silently diverging from the website.
import 'package:flutter_test/flutter_test.dart';
import 'package:propcid_app/screens/post_property/listing_validators.dart';

void main() {
  group('isBlank', () {
    test('false is an ANSWER, not a blank', () {
      // The single most consequential case: an unchecked required checkbox
      // satisfies a required-field rule on the web.
      expect(isBlank(false), isFalse);
      expect(isBlank(true), isFalse);
    });

    test('null and whitespace-only strings are blank', () {
      expect(isBlank(null), isTrue);
      expect(isBlank(''), isTrue);
      expect(isBlank('   '), isTrue);
      expect(isBlank('\t\n'), isTrue);
    });

    test('0 is not blank; NaN is', () {
      expect(isBlank(0), isFalse);
      expect(isBlank(-1), isFalse);
      expect(isBlank(double.nan), isTrue);
    });

    test('empty collections are blank, non-empty are not', () {
      expect(isBlank(<String>[]), isTrue);
      expect(isBlank(<String>['a']), isFalse);
      expect(isBlank(<String, String>{}), isTrue);
      expect(isBlank(<String, String>{'a': 'b'}), isFalse);
      expect(isBlank(<String>{}), isTrue);
    });
  });

  group('positiveNumber — JS Number() coercion', () {
    final v = positiveNumber('Price');

    test('empty input reports "greater than 0", NOT "must be a number"', () {
      // Number('') === 0 in JS, so the <= 0 branch wins. Dart's
      // double.tryParse('') is null, which would have taken the other branch
      // and shown a different message than the website.
      expect(v(''), 'Price must be greater than 0.');
    });

    test('non-numeric text strips to empty, so also "greater than 0"', () {
      expect(v('abc'), 'Price must be greater than 0.');
    });

    test('zero and negatives rejected', () {
      expect(v('0'), 'Price must be greater than 0.');
      expect(v('-5'), 'Price must be greater than 0.');
    });

    test('currency formatting is stripped before parsing', () {
      expect(v(r'₹ 12,50,000'), isNull);
      expect(v('1 200'), isNull);
    });

    test('genuinely unparseable input reports "must be a number"', () {
      // '1.2.3' survives stripping but Number() yields NaN.
      expect(v('1.2.3'), 'Price must be a number.');
      expect(v('-'), 'Price must be a number.');
    });

    test('valid positives pass', () {
      expect(v('1'), isNull);
      expect(v('0.5'), isNull);
      expect(v(2500), isNull);
    });
  });

  group('nonNegativeNumber', () {
    final v = nonNegativeNumber('Floor');

    test('zero is allowed (floor numbers, balcony counts)', () {
      expect(v('0'), isNull);
      expect(v(''), isNull); // Number('') === 0, and 0 is allowed here
    });

    test('negatives rejected with the cannot-be-negative message', () {
      expect(v('-1'), 'Floor cannot be negative.');
    });
  });

  group('PATTERN regexes', () {
    test('pincode is exactly 6 digits', () {
      expect(validPincode('560001'), isNull);
      expect(validPincode(' 560001 '), isNull); // React trims pincode
      expect(validPincode('56001'), isNotNull);
      expect(validPincode('5600011'), isNotNull);
      expect(validPincode('56000a'), isNotNull);
    });

    test('phone allows +, digits, spaces and hyphens, length 8-15', () {
      expect(validPhone('+91 98765 43210'), isNull);
      expect(validPhone('9876543210'), isNull);
      expect(validPhone('98765-43210'), isNull);
      expect(validPhone('1234567'), isNotNull); // 7 chars, below minimum
      expect(validPhone('+9876543210987654'), isNotNull); // over 15
      expect(validPhone('98765abcde'), isNotNull);
    });

    test('email requires a dot in the domain and no whitespace', () {
      expect(validEmail('a@b.co'), isNull);
      expect(validEmail('a@b'), isNotNull);
      expect(validEmail('a b@c.co'), isNotNull);
      expect(validEmail('@b.co'), isNotNull);
    });

    test('email is NOT trimmed, unlike phone and pincode', () {
      // React calls PATTERN.EMAIL.test(String(value)) with no .trim(), while
      // pincode and phone both trim. Preserved deliberately.
      expect(validEmail(' a@b.co'), isNotNull);
      expect(validPhone(' 9876543210 '), isNull);
    });
  });

  group('minLength', () {
    test('counts trimmed length', () {
      final v = minLength(3, 'Title');
      expect(v('ab'), 'Title must be at least 3 characters.');
      expect(v('  a  '), isNotNull);
      expect(v('abc'), isNull);
    });
  });

  group('summariseIssues', () {
    test('formats like the web toast', () {
      expect(summariseIssues([]), '');
      expect(summariseIssues(['Area']), 'Area');
      expect(summariseIssues(['Area', 'Beds']), 'Area and Beds');
      expect(summariseIssues(['A', 'B', 'C']), 'A, B and C');
      expect(summariseIssues(['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']),
          'A, B, C, D and 4 more');
    });
  });
}
