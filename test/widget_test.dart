// Basic Flutter widget test for Pixel Lights app.

import 'package:flutter_test/flutter_test.dart';

import 'package:pixel_lights/main.dart';

void main() {
  testWidgets('App smoke test - app renders without crashing', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const PixelLightsApp());

    // Verify the app title is present
    expect(find.text('Pixel Lights'), findsOneWidget);
  });
}
