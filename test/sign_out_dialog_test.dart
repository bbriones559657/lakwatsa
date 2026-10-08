import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/screens/auth/sign_out_dialog.dart';

Future<void> openDialog(
  WidgetTester tester,
  Future<void> Function() signOut,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => SignOutDialog(signOut: signOut),
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('auth-driven dismissal cannot pop the underlying route twice', (
    tester,
  ) async {
    final completion = Completer<void>();
    await openDialog(tester, () => completion.future);
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    final context = tester.element(find.byType(SignOutDialog));
    final navigator = Navigator.of(context);
    navigator.pop(); // AuthGate can remove the dialog before signOut resolves.
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel leaves the account signed in', (tester) async {
    var calls = 0;
    await openDialog(tester, () async {
      calls++;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(SignOutDialog), findsNothing);
  });

  testWidgets('sign out is single-flight and blocks Back until completion', (
    tester,
  ) async {
    final completion = Completer<void>();
    var calls = 0;
    await openDialog(tester, () {
      calls++;
      return completion.future;
    });
    await tester.tap(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Signing out...'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(SignOutDialog), findsOneWidget);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SignOutDialog), findsNothing);
  });

  testWidgets('sign out failure shows a recoverable error', (tester) async {
    var calls = 0;
    await openDialog(tester, () async {
      calls++;
      if (calls == 1) throw StateError('offline');
    });
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Could not sign out. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(SignOutDialog), findsNothing);
  });
}
