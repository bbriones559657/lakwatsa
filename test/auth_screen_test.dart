import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lakwatsa/app/auth_screen.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'sign in validates email and password without a network request',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(find.text('Use at least 6 characters.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('registration switches form and fits a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
