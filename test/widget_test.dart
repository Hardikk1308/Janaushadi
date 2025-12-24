// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jan_aushadi/main.dart';

void main() {
  testWidgets('SplashScreen displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the SplashScreen is displayed (pump once for initial render)
    await tester.pump();

    // Verify that Image widgets are present (for the janaushdhi.jpg image)
    expect(find.byType(Image), findsWidgets);

    // Allow the pending timer to complete without waiting
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  });
}
