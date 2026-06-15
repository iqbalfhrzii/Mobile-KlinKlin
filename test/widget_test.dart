// This is a basic Flutter widget test for Klinklin app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klinklin/app/app.dart';

void main() {
  testWidgets('Klinklin home page smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const KlinklinApp());

    // Verify that the app title is shown.
    expect(find.text('Klinklin'), findsOneWidget);

    // Verify that the hero banner text is shown.
    expect(find.text('Klinklin App'), findsOneWidget);

    // Verify that the welcome section is shown.
    expect(find.text('Selamat Datang'), findsOneWidget);
  });
}
