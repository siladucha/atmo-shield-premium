import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atmo_shield_premium/main_generator.dart';

void main() {
  testWidgets('HealthKit Data Generator app launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HealthKitDataGeneratorApp());

    // Verify that the generation screen is displayed
    expect(find.text('Generate Test Data'), findsOneWidget);
    expect(find.text('Generate 1 Year Data'), findsOneWidget);
  });
}
