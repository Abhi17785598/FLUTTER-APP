// T2 validation-parity guard.
//
// migration-specification Task 2: "table-driven tests per category x listingType
// asserting the same steps pass/fail as React for identical input."
//
// The rule table is a direct port of propertyListingRules.ts, so these tests
// assert the *guards* — which rules fire for which category/listingType — since
// that is where a port silently diverges. The engine internals (isBlank, the
// numeric coercion, the regexes) are pinned separately in
// listing_validators_parity_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propcid_app/providers/post_property_provider.dart';
import 'package:propcid_app/screens/post_property/listing_validation_rules.dart';

/// Rule fields that fire for the given category/listingType with empty data,
/// evaluated ungated so the comparison is against React's table, not against
/// what Flutter can currently fill.
Set<String> firingFields(
  String step,
  PropertyCategory category,
  ListingIntent intent,
) {
  final p = PostPropertyProvider()
    ..setCategory(category)
    ..setListingIntent(intent);
  return validatePropertyStep(step, ListingFormData(p), onlyCollectable: false)
      .map((i) => i.field)
      .toSet();
}

void main() {
  setUp(() => WidgetsFlutterBinding.ensureInitialized());

  group('Step visibility of rules by category', () {
    test('land gets land dimensions, never bedrooms or soil-free fields', () {
      final f = firingFields('Dimensions', PropertyCategory.land, ListingIntent.sell);
      expect(f, containsAll(<String>[
        'front', 'back', 'right', 'left', 'surveyNumber', 'fsiFarAllowed',
        'floorAllowed', 'heightRestriction', 'soilType', 'area', 'availableFrom',
      ]));
      expect(f, isNot(contains('bedrooms')));
      expect(f, isNot(contains('bathrooms')));
      expect(f, isNot(contains('carpetArea')));
      expect(f, isNot(contains('bhkType')));
    });

    test('residential gets BHK block, never land dimensions', () {
      final f = firingFields(
          'Dimensions', PropertyCategory.residential, ListingIntent.sell);
      expect(f, containsAll(<String>[
        'bhkType', 'bedrooms', 'bathrooms', 'balconies', 'carpetArea',
        'totalFloors', 'propertyCondition', 'area', 'availableFrom',
      ]));
      expect(f, isNot(contains('soilType')));
      expect(f, isNot(contains('surveyNumber')));
    });

    test('commercial does NOT require plain area (it has no such input)', () {
      // propertyListingRules.ts:94 — commercial mirrors superBuiltUpArea into
      // area, so requiring `area` would be an error with no field to fix it.
      final f = firingFields(
          'Dimensions', PropertyCategory.commercial, ListingIntent.sell);
      expect(f, isNot(contains('area')));
      expect(f, containsAll(<String>[
        'buildingName', 'buildingCode', 'buildingType', 'totalFloorsBuilding',
        'plotArea', 'superBuiltUpArea',
      ]));
    });

    test('PG requires facing and carpet area, not BHK', () {
      final f =
          firingFields('Dimensions', PropertyCategory.pg, ListingIntent.rent);
      expect(f, contains('facing'));
      expect(f, contains('carpetArea'));
      expect(f, contains('totalFloors'));
      expect(f, isNot(contains('bhkType')));
      // availableFrom is land/residential only on this step.
      expect(f, isNot(contains('availableFrom')));
    });

    test('others requires carpet area but no category-specific block', () {
      final f = firingFields(
          'Dimensions', PropertyCategory.other, ListingIntent.sell);
      expect(f, contains('carpetArea'));
      expect(f, contains('area'));
      expect(f, isNot(contains('soilType')));
      expect(f, isNot(contains('bedrooms')));
      expect(f, isNot(contains('buildingName')));
    });
  });

  group('landUseMasterPlan is rent-only for land (Q7)', () {
    test('required when renting land', () {
      final f =
          firingFields('Dimensions', PropertyCategory.land, ListingIntent.rent);
      expect(f, contains('landUseMasterPlan'));
    });

    test('NOT required when selling or leasing land', () {
      for (final intent in [ListingIntent.sell, ListingIntent.lease]) {
        final f = firingFields('Dimensions', PropertyCategory.land, intent);
        expect(f, isNot(contains('landUseMasterPlan')),
            reason: 'should not fire for ${intent.name}');
      }
    });
  });

  group('Apartment vs house branching', () {
    ListingFormData withSubtype(String subtype) {
      final p = PostPropertyProvider()
        ..setCategory(PropertyCategory.residential)
        ..setListingIntent(ListingIntent.rent)
        ..setResidentialSubType(subtype);
      return ListingFormData(p);
    }

    Set<String> fields(String step, String subtype) =>
        validatePropertyStep(step, withSubtype(subtype), onlyCollectable: false)
            .map((i) => i.field)
            .toSet();

    test('apartment subtype requires floorNo and societyCharges', () {
      final dims = fields('Dimensions', 'Flat');
      expect(dims, contains('floorNo'));
      expect(dims, isNot(contains('builtUpArea')));

      final pricing = fields('Pricing', 'Flat');
      expect(pricing, contains('societyCharges'));
      expect(pricing, isNot(contains('maintenanceCharges')));
    });

    test('house subtype requires builtUpArea and maintenanceCharges', () {
      final dims = fields('Dimensions', 'Villa / Kothi');
      expect(dims, contains('builtUpArea'));
      expect(dims, isNot(contains('floorNo')));

      final pricing = fields('Pricing', 'Villa / Kothi');
      expect(pricing, contains('maintenanceCharges'));
      expect(pricing, isNot(contains('societyCharges')));
    });

    test('a LEGACY subtype string falls into the house branch', () {
      // 'Studio Apartment' is Flutter's legacy spelling; the canonical value is
      // 'Studio / Service Apartment'. T1 aliases it on read, but if an
      // un-aliased value ever reaches the rules it is treated as a house —
      // which is exactly why the alias matters.
      final dims = fields('Dimensions', 'Studio Apartment');
      expect(dims, contains('builtUpArea'));

      final canonical = fields('Dimensions', 'Studio / Service Apartment');
      expect(canonical, isNot(contains('builtUpArea')));
      expect(canonical, contains('floorNo'));
    });
  });

  group('Pricing rules by listing type', () {
    Set<String> pricing(PropertyCategory c, ListingIntent i) =>
        firingFields('Pricing', c, i);

    test('sell requires ratePerArea except for PG', () {
      expect(pricing(PropertyCategory.residential, ListingIntent.sell),
          contains('ratePerArea'));
      expect(pricing(PropertyCategory.pg, ListingIntent.sell),
          isNot(contains('ratePerArea')));
    });

    test('PG rent uses per-bed rent instead of price', () {
      final f = pricing(PropertyCategory.pg, ListingIntent.rent);
      expect(f, contains('monthlyRentPerBed'));
      expect(f, isNot(contains('price')));
      expect(f, containsAll(<String>['foodCharges', 'laundryCharges']));
    });

    test('PG lease DOES require price (only rent/sell are exempt)', () {
      // applies: !(isPg && listingType !== 'lease')
      final f = pricing(PropertyCategory.pg, ListingIntent.lease);
      expect(f, contains('price'));
    });

    test('PG sell requires sale price and occupancy, not lockInPeriod', () {
      final f = pricing(PropertyCategory.pg, ListingIntent.sell);
      expect(f, containsAll(<String>['totalSalePrice', 'occupancyRate']));
      expect(f, isNot(contains('lockInPeriod')));
    });

    test('rent/lease require deposit; sell does not', () {
      expect(pricing(PropertyCategory.residential, ListingIntent.rent),
          contains('securityDeposit'));
      expect(pricing(PropertyCategory.residential, ListingIntent.sell),
          isNot(contains('securityDeposit')));
    });

    test('commercial lease terms only for rent/lease, ROI only for sell', () {
      final rent = pricing(PropertyCategory.commercial, ListingIntent.rent);
      expect(rent, containsAll(<String>[
        'leaseDuration', 'leaseEscalationPercent', 'camCharges', 'fitOutPeriod',
      ]));
      expect(rent, isNot(contains('roiEstimate')));

      final sell = pricing(PropertyCategory.commercial, ListingIntent.sell);
      expect(sell, containsAll(<String>['roiEstimate', 'currentRentalIncome']));
      expect(sell, isNot(contains('camCharges')));
    });

    test('land never requires maintenanceCharges on rent', () {
      final f = pricing(PropertyCategory.land, ListingIntent.rent);
      expect(f, isNot(contains('maintenanceCharges')));
    });

    test('tokenAmount and brokerage are required for every combination', () {
      for (final c in PropertyCategory.values) {
        for (final i in ListingIntent.values) {
          final f = pricing(c, i);
          expect(f, contains('tokenAmount'), reason: '${c.name}/${i.name}');
          expect(f, contains('brokerage'), reason: '${c.name}/${i.name}');
        }
      }
    });
  });

  group('Other steps', () {
    test('amenities rule fires for residential and others only', () {
      expect(firingFields('Amenities', PropertyCategory.residential,
          ListingIntent.sell), contains('amenities'));
      expect(firingFields('Amenities', PropertyCategory.other,
          ListingIntent.sell), contains('amenities'));
      expect(firingFields('Amenities', PropertyCategory.pg, ListingIntent.rent),
          contains('pgAmenities'));
      expect(firingFields('Amenities', PropertyCategory.land, ListingIntent.sell),
          isEmpty);
    });

    test('legal step is land ownership + PG quiet hours only', () {
      expect(firingFields('Legal', PropertyCategory.land, ListingIntent.sell),
          containsAll(<String>['ownershipType', 'ownerName']));
      expect(firingFields('Legal', PropertyCategory.pg, ListingIntent.rent),
          contains('quietHours'));
      expect(
          firingFields('Legal', PropertyCategory.residential, ListingIntent.sell),
          isEmpty);
    });

    test('media/contact rules are category-independent except PG extras', () {
      final res = firingFields(
          'Media', PropertyCategory.residential, ListingIntent.sell);
      expect(res, containsAll(<String>[
        'mediaFiles', 'contactName', 'contactPhone', 'contactEmail',
        'whatsappNumber', 'bestTimeToCall', 'hashtags',
      ]));
      expect(res, isNot(contains('ownerManagerName')));

      final pg = firingFields('Media', PropertyCategory.pg, ListingIntent.rent);
      expect(pg, containsAll(<String>['ownerManagerName', 'alternateNumber']));
    });
  });

  group('Enforcement gate', () {
    test('un-collectable rules never block a save', () {
      // The map pin has no picker in any category, so its rule must be
      // evaluated (parity with React) but never block.
      final p = PostPropertyProvider()
        ..setCategory(PropertyCategory.residential)
        ..setListingIntent(ListingIntent.sell);

      final gated = validatePropertyStep('Basic Info', ListingFormData(p))
          .map((i) => i.field)
          .toSet();
      final ungated = validatePropertyStep('Basic Info', ListingFormData(p),
              onlyCollectable: false)
          .map((i) => i.field)
          .toSet();

      expect(ungated, contains('latitude'));
      expect(gated, isNot(contains('latitude')));
      // Fields Flutter DOES collect are still enforced.
      expect(gated, containsAll(<String>['title', 'city', 'state']));
    });

    test('the not-yet-collectable set is down to the map pin', () {
      // This list shrank with every category phase. All ten have landed, so
      // the only rule field without an input is the map pin — which is not
      // category-specific and has no picker in any flow.
      expect(kFieldsNotYetCollectable, {'latitude'});
    });
  });

  group('Grandfathering', () {
    test('new listings are validated in full', () {
      final p = PostPropertyProvider();
      expect(p.grandfatheredBlankFields, isEmpty);
      expect(p.isStepValid(0), isFalse); // category/listingType missing
    });

    test('fields blank at load time are exempt for that edit session', () {
      final p = PostPropertyProvider();
      p.initFromRawData(
        editingPropertyId: 'p1',
        propertyRow: {
          'category': 'residential',
          'property_type': 'sell',
          'title': 'Old listing',
          'metadata': <String, dynamic>{},
        },
      );

      // The row has no description/city/etc., so those were blank on load and
      // must not block re-saving it.
      expect(p.grandfatheredBlankFields, contains('description'));
      expect(p.grandfatheredBlankFields, contains('city'));
      expect(p.isStepValid(1), isTrue,
          reason: 'pre-existing blanks must not block an edit');
    });

    test('a field the user fills is validated normally again', () {
      final p = PostPropertyProvider();
      p.initFromRawData(
        editingPropertyId: 'p1',
        propertyRow: {
          'category': 'residential',
          'property_type': 'sell',
          'metadata': <String, dynamic>{},
        },
      );
      expect(p.grandfatheredBlankFields, contains('pincode'));

      // While still blank, the required check is suppressed.
      expect(p.issuesForStep(1).map((i) => i.field), isNot(contains('pincode')));

      // Once the user types something, the FORMAT check applies again —
      // grandfathering exempts "you must supply a value", not validation
      // itself. A 2-digit pincode is invalid on the web too.
      p.setPincode('12');
      expect(p.issuesForStep(1).map((i) => i.field), contains('pincode'));

      // ...and a valid one clears it.
      p.setPincode('560001');
      expect(p.issuesForStep(1).map((i) => i.field), isNot(contains('pincode')));
    });
  });

  group('Provider wiring', () {
    test('step getters and canGoNext are rules-driven', () {
      final p = PostPropertyProvider();
      expect(p.isStep1Valid, isFalse);
      expect(p.canGoNext, isFalse);

      p
        ..setCategory(PropertyCategory.residential)
        ..setListingIntent(ListingIntent.sell);
      expect(p.isStep1Valid, isTrue);
      expect(p.canGoNext, isTrue);
    });

    test('Amenities and Legal are no longer unconditionally valid', () {
      // isStep5Valid / isStep6Valid used to `return true` outright.
      final p = PostPropertyProvider()
        ..setCategory(PropertyCategory.residential)
        ..setListingIntent(ListingIntent.sell);
      expect(p.isStep5Valid, isFalse, reason: 'amenities now required');

      final land = PostPropertyProvider()
        ..setCategory(PropertyCategory.land)
        ..setListingIntent(ListingIntent.sell);
      // T8 gave ownershipType/ownerName real inputs, so Legal now blocks for
      // land instead of being gated clean.
      expect(land.isStep6Valid, isFalse);
      land
        ..setText('ownershipType', 'Freehold')
        ..setText('ownerName', 'A. Sharma');
      expect(land.isStep6Valid, isTrue);
    });

    test('firstInvalidStep points at the earliest problem', () {
      final p = PostPropertyProvider();
      expect(p.firstInvalidStep, 0);

      p
        ..setCategory(PropertyCategory.residential)
        ..setListingIntent(ListingIntent.sell);
      expect(p.firstInvalidStep, 1);
    });
  });
}
