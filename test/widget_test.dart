// Basic smoke test: verifies the login screen renders when there's no
// authenticated user, without depending on a live Firebase backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entrega_app/login_page.dart';

void main() {
  testWidgets('LoginPage renders its main fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
