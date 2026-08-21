// Pins the Schedule Visit / Enquiry sheets' validation and error-mapping
// rules — `BookVisitModal.tsx:112-130,344-350` transcribed into
// `VisitFormValidation`, plus the [StateError]-vs-generic-error split in
// `describeSubmitError`. Pure functions; no widget, no Supabase client.
import 'package:flutter_test/flutter_test.dart';
import 'package:propcid_app/screens/property_detail/booking_enquiry_validation.dart';

void main() {
  group('VisitFormValidation.nameError', () {
    test('empty name is required', () {
      expect(VisitFormValidation.nameError(''), 'Name is required');
      expect(VisitFormValidation.nameError('   '), 'Name is required');
    });

    test('digits or symbols are rejected', () {
      expect(
        VisitFormValidation.nameError('Asha123'),
        'Name should only contain alphabets',
      );
    });

    test('a plain alphabetic name (with spaces) is accepted', () {
      expect(VisitFormValidation.nameError('Asha Rao'), isNull);
    });
  });

  group('VisitFormValidation.phoneError', () {
    test('empty phone is required', () {
      expect(VisitFormValidation.phoneError(''), 'Phone number required');
    });

    test('fewer than 10 digits is rejected', () {
      expect(
        VisitFormValidation.phoneError('98765'),
        'Enter valid 10 digit mobile number',
      );
    });

    test('a 10-digit phone is accepted', () {
      expect(VisitFormValidation.phoneError('9876543210'), isNull);
    });
  });

  group('VisitFormValidation.isSlotDisabled', () {
    test('never disabled for a future date, regardless of the hour', () {
      final future = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 9, 23);
      expect(VisitFormValidation.isSlotDisabled('10:00', future, now), isFalse);
    });

    test('disabled for today once the slot\'s leading number is <= the current hour', () {
      final today = DateTime(2026, 9, 9);
      final now = DateTime(2026, 9, 9, 2, 30); // 2:30am
      // BookVisitModal.tsx's exact (quirky) comparison: "02:00"'s leading
      // number (2) <= the current hour (2) disables it, even though "02:00"
      // is meant to represent 2 PM.
      expect(VisitFormValidation.isSlotDisabled('02:00', today, now), isTrue);
      expect(VisitFormValidation.isSlotDisabled('04:00', today, now), isFalse);
    });
  });

  group('describeSubmitError', () {
    test('a StateError\'s own message is shown verbatim', () {
      expect(
        describeSubmitError(StateError('Sign in to book a visit.'), "Couldn't book this visit"),
        'Sign in to book a visit.',
      );
    });

    test('any other error surfaces its own text with the given prefix', () {
      expect(
        describeSubmitError(Exception('network unreachable'), "Couldn't book this visit"),
        contains('network unreachable'),
      );
    });
  });
}
