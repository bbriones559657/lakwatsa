import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/screens/auth/sign_in_screen.dart';

void main() {
  testWidgets(
    'switching auth mode clears stale validation without clearing credentials',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignInScreen()));

      final createAccountModeButton = find.text(
        'New to Lakwatsa? Create account',
      );
      await tester.ensureVisible(createAccountModeButton);
      await tester.tap(createAccountModeButton);
      await tester.pumpAndSettle();

      var fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(0), 'user@example.com');
      await tester.enterText(fields.at(1), '123');
      await tester.enterText(fields.at(2), '123');

      final createAccountButton = find.text('Create Account');
      await tester.ensureVisible(createAccountButton);
      await tester.tap(createAccountButton);
      await tester.pump();

      expect(find.text('Use at least 6 characters.'), findsOneWidget);

      final signInModeButton = find.text('Already have an account? Sign in');
      await tester.ensureVisible(signInModeButton);
      await tester.tap(signInModeButton);
      await tester.pumpAndSettle();

      expect(find.text('Use at least 6 characters.'), findsNothing);

      fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller?.text,
        'user@example.com',
      );
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller?.text,
        '123',
      );
    },
  );

  testWidgets('Login and Register share the official backpack image', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));

    void expectBranding() {
      final imageFinder = find.byKey(const Key('auth-backpack-logo'));
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(
        (image.image as AssetImage).assetName,
        'assets/branding/splash_logo.png',
      );
      expect(image.width, 160);
      expect(image.height, 160);
      expect(image.fit, BoxFit.contain);
      expect(find.text('LK'), findsNothing);
      expect(
        tester.getCenter(find.byKey(const Key('auth-brand-mark'))).dx,
        closeTo(160, 1),
      );
      expect(tester.takeException(), isNull);
    }

    expectBranding();
    final createAccount = find.text('New to Lakwatsa? Create account');
    await tester.ensureVisible(createAccount);
    await tester.tap(createAccount);
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expectBranding();

    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.tap(find.byType(TextFormField).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.ensureVisible(find.text('Create Account'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
