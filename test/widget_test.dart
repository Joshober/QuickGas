// This is a basic Flutter widget test for QuickGas app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quickgas/main.dart';

void main() {
  testWidgets('App initializes without errors', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Wait for async initialization
    await tester.pumpAndSettle();

    // Verify that the app loads without errors
    // The login screen should be visible since user is not authenticated
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
