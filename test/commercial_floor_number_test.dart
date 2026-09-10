// Commercial → Step 3 → Floor-wise Inventory → per-floor "Floor Number"
// field. Relabelled from "Floor Name" (a free-text field) to a numeric-only
// "Floor Number" capped at 50 — the storage key (`floorName` on
// `buildingInventory.floors[]`) is unchanged, only the label and the input
// rules are.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:propcid_app/providers/post_property_provider.dart';
import 'package:propcid_app/screens/post_property/portal_kit.dart';
import 'package:propcid_app/screens/post_property/steps/property_dimensions_step.dart';

void main() {
  Future<PostPropertyProvider> pumpOneFloor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = PostPropertyProvider()
      ..setCategory(PropertyCategory.commercial)
      ..setListingIntent(ListingIntent.rent);
    p.setBuildingInventoryValue('totalFloorsBuilding', '1');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: p,
          child: const Scaffold(
            body: SingleChildScrollView(child: PropertyDimensionsStep()),
          ),
        ),
      ),
    );
    await tester.pump();
    return p;
  }

  Finder floorNumberTextField() => find.descendant(
    of: find.ancestor(
      of: find.text('Floor Number'),
      matching: find.byType(PortalLabelledField),
    ),
    matching: find.byType(TextField),
  );

  testWidgets('renders as "Floor Number", not "Floor Name"', (tester) async {
    await pumpOneFloor(tester);
    expect(find.text('Floor Number'), findsOneWidget);
    expect(find.text('Floor Name'), findsNothing);
  });

  testWidgets('accepts a value up to 50', (tester) async {
    final p = await pumpOneFloor(tester);
    await tester.enterText(floorNumberTextField(), '50');
    await tester.pump();
    expect(p.buildingFloorEntry(1)?['floorName'], '50');
  });

  testWidgets('rejects a value over 50, leaving the field unchanged', (
    tester,
  ) async {
    final p = await pumpOneFloor(tester);
    await tester.enterText(floorNumberTextField(), '30');
    await tester.pump();
    await tester.enterText(floorNumberTextField(), '51');
    await tester.pump();
    expect(p.buildingFloorEntry(1)?['floorName'], '30');
  });

  testWidgets('strips non-digit characters', (tester) async {
    final p = await pumpOneFloor(tester);
    await tester.enterText(floorNumberTextField(), '4a5');
    await tester.pump();
    expect(p.buildingFloorEntry(1)?['floorName'], '45');
  });

  testWidgets('never blocks the empty string (clearing the field)', (
    tester,
  ) async {
    final p = await pumpOneFloor(tester);
    await tester.enterText(floorNumberTextField(), '25');
    await tester.pump();
    await tester.enterText(floorNumberTextField(), '');
    await tester.pump();
    expect(p.buildingFloorEntry(1)?['floorName'], '');
  });
}
