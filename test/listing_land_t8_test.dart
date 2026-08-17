// T8 land-parity guard.
//
// Land was the largest gap: Flutter rendered nothing land-specific beyond two
// free-text boxes, so every land rule fired with no field to satisfy it, and
// four of the six properties_land columns were never written.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propcid_app/providers/post_property_provider.dart';
import 'package:propcid_app/screens/post_property/listing_constants.dart';
import 'package:propcid_app/screens/post_property/listing_validation_rules.dart';

PostPropertyProvider land({ListingIntent intent = ListingIntent.sell}) =>
    PostPropertyProvider()
      ..setCategory(PropertyCategory.land)
      ..setListingIntent(intent);

Set<String> blockers(PostPropertyProvider p, WizardStep step) {
  final i = p.visibleSteps.indexOf(step);
  if (i == -1) return const <String>{};
  return p.issuesForStep(i).map((e) => e.field).toSet();
}

/// Mirrors PropertyService._landRow.
Map<String, dynamic> landRow(PostPropertyProvider p) => {
      'property_id': 'prop-1',
      'area_sqft': double.tryParse(p.area) ?? 0,
      'boundary_wall': p.boolVal('boundary'),
      'water_source': p.text('waterSource'),
      'road_width_ft': double.tryParse(p.text('roadWidth')) ?? 0,
      'soil_type': p.text('soilType'),
      'slope_percentage': 0,
    };

void main() {
  setUp(() => WidgetsFlutterBinding.ensureInitialized());

  group('Land specification fields are reachable', () {
    test('every land rule is now collectable', () {
      for (final intent in ListingIntent.values) {
        final p = land(intent: intent);
        final all = <String>{
          for (var i = 0; i < p.visibleSteps.length; i++)
            ...p.issuesForStep(i).map((e) => e.field),
        };
        for (final f in all) {
          expect(kFlutterCollectableFields, contains(f),
              reason: '$f blocks land/${intent.name} with no input');
        }
      }
    });

    test('the four side dimensions each block until filled', () {
      final p = land();
      final b = blockers(p, WizardStep.dimensions);
      expect(b, containsAll(<String>['front', 'back', 'right', 'left']));

      for (final dim in ['front', 'back', 'right', 'left']) {
        p.setText(dim, '40');
      }
      final after = blockers(p, WizardStep.dimensions);
      for (final dim in ['front', 'back', 'right', 'left']) {
        expect(after, isNot(contains(dim)));
      }
    });

    test('Khasra and soil block until filled; FSI/FAR, floors and height are optional', () {
      // fsiFarAllowed/floorAllowed/heightRestriction are collected but have
      // no rule at all in the portal's propertyListingRules.ts for Land —
      // they're optional there, so they must never appear as blockers here.
      final p = land();
      expect(
          blockers(p, WizardStep.dimensions),
          containsAll(<String>['surveyNumber', 'soilType']));
      for (final f in ['fsiFarAllowed', 'floorAllowed', 'heightRestriction']) {
        expect(blockers(p, WizardStep.dimensions), isNot(contains(f)));
      }

      p
        ..setText('surveyNumber', '123/4')
        ..setText('soilType', 'Alluvial Soil');

      final after = blockers(p, WizardStep.dimensions);
      for (final f in ['surveyNumber', 'soilType']) {
        expect(after, isNot(contains(f)));
      }
    });
  });

  group('landUseMasterPlan is rent-only', () {
    test('blocks on rent', () {
      expect(blockers(land(intent: ListingIntent.rent), WizardStep.dimensions),
          contains('landUseMasterPlan'));
    });

    test('does not block on sell or lease', () {
      for (final intent in [ListingIntent.sell, ListingIntent.lease]) {
        expect(blockers(land(intent: intent), WizardStep.dimensions),
            isNot(contains('landUseMasterPlan')),
            reason: intent.name);
      }
    });
  });

  group('Land legal', () {
    test('ownership type and owner name block until filled', () {
      final p = land();
      expect(blockers(p, WizardStep.legal),
          containsAll(<String>['ownershipType', 'ownerName']));

      p
        ..setText('ownershipType', 'Freehold')
        ..setText('ownerName', 'A. Sharma');
      expect(blockers(p, WizardStep.legal), isEmpty);
    });

    test('ownership options are React\'s four', () {
      expect(kLandOwnershipTypes, [
        'Freehold', 'Leasehold', 'Power of Attorney', 'Co-Operative Society',
      ]);
    });

    test('the seven land record flags default false and toggle', () {
      const flags = [
        'mutationAvailable', 'registryAvailable', 'pattaAvailable',
        'khataAvailable', 'jamabandiAvailable', 'courtCasePending',
        'bankLoanApproved',
      ];
      final p = land();
      for (final f in flags) {
        expect(p.boolVal(f), isFalse);
      }
      p.setBoolVal('jamabandiAvailable', true);
      expect(p.boolVal('jamabandiAvailable'), isTrue);
      // false is a deliberate answer, not a blank — these never block.
      expect(blockers(p, WizardStep.legal), isNot(contains('courtCasePending')));
    });
  });

  group('Subtype drives the type list', () {
    test('changing subtype clears landType', () {
      // React: onValueChange sets landSubtype then blanks landType, because
      // the two option sets are disjoint.
      final p = land()
        ..setText('landSubtype', 'land')
        ..setText('landType', 'Agriculture Land');
      expect(p.text('landType'), 'Agriculture Land');

      p
        ..setText('landSubtype', 'plot')
        ..setText('landType', '');
      expect(p.text('landType'), isEmpty);
    });

    test('the two option sets are disjoint', () {
      expect(kLandTypeOptions.toSet().intersection(kPlotTypeOptions.toSet()),
          isEmpty);
      expect(kLandSubtypes, ['land', 'plot']);
    });

    test('landType values come from the right set', () {
      expect(kLandTypeOptions, contains('Agriculture Land'));
      expect(kPlotTypeOptions, ['Residential Plot', 'Commercial Plot']);
    });
  });

  group('Unit sets', () {
    test('side dimensions offer three units, height offers two', () {
      // Rendered from different selects in React; conflating them would store
      // a unit the web never writes.
      expect(kLandSideDimensionUnits, ['ft', 'm', 'yards']);
      expect(kHeightRestrictionUnits, ['ft', 'm']);
    });

    test('land area units are the full 15-unit set', () {
      expect(kAreaUnitsByPropertyType['land']!.length, 15);
      expect(kDefaultAreaUnitByPropertyType['land'], 'acres');
    });

    test('soil types are React\'s 18, not the spec\'s truncated 8', () {
      expect(kLandSoilTypes.length, 18);
      expect(kLandSoilTypes.first, 'Alluvial Soil');
      expect(kLandSoilTypes, contains('Filled/Reclaimed Land'));
    });
  });

  group('properties_land subtable', () {
    test('all six columns are written, none conditionally', () {
      final row = landRow(land()..setArea('5000'));
      expect(row.keys, containsAll(<String>[
        'property_id', 'area_sqft', 'boundary_wall', 'water_source',
        'road_width_ft', 'soil_type', 'slope_percentage',
      ]));
    });

    test('nothing is null even when nothing was entered', () {
      // React's dbNum/dbBool/dbText exist so this table never carries a NULL;
      // Flutter previously left four columns unwritten.
      final row = landRow(land());
      for (final e in row.entries) {
        expect(e.value, isNotNull, reason: '${e.key} must not be null');
      }
      expect(row['area_sqft'], 0);
      expect(row['boundary_wall'], isFalse);
      expect(row['water_source'], '');
      expect(row['road_width_ft'], 0);
      expect(row['slope_percentage'], 0);
    });

    test('slope_percentage is always 0 — not collected by either wizard', () {
      expect(landRow(land())['slope_percentage'], 0);
    });

    test('collected values reach the row', () {
      final p = land()
        ..setArea('5000')
        ..setText('soilType', 'Black Soil');
      final row = landRow(p);
      expect(row['area_sqft'], 5000);
      expect(row['soil_type'], 'Black Soil');
    });
  });

  group('Step visibility', () {
    test('land hides Condition and Amenities', () {
      final p = land();
      expect(p.visibleSteps, isNot(contains(WizardStep.condition)));
      expect(p.visibleSteps, isNot(contains(WizardStep.amenities)));
      expect(p.totalSteps, 7);
    });

    test('land is never asked for residential or commercial fields', () {
      final b = blockers(land(), WizardStep.dimensions);
      expect(b, isNot(contains('bhkType')));
      expect(b, isNot(contains('carpetArea')));
      expect(b, isNot(contains('buildingName')));
    });
  });
}
