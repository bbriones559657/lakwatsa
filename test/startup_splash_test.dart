import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lakwatsa/main.dart';
import 'package:lakwatsa/screens/auth/auth_gate.dart';
import 'package:lakwatsa/screens/auth/sign_in_screen.dart';
import 'package:lakwatsa/screens/splash_screen.dart';
import 'package:lakwatsa/theme/app_theme.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'test-user';
}

void main() {
  testWidgets('splash stays visible during Firebase initialization', (
    tester,
  ) async {
    final initialization = Completer<void>();
    var initializationCalls = 0;
    var authGateBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          initialize: () {
            initializationCalls++;
            return initialization.future;
          },
          authGateBuilder: (_) {
            authGateBuilds++;
            return const Scaffold(body: Text('Authenticated destination'));
          },
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('PACK SMART. SCAN EASY.'), findsOneWidget);
    expect(initializationCalls, 1);
    expect(authGateBuilds, 0);

    initialization.complete();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Authenticated destination'), findsOneWidget);
    expect(initializationCalls, 1);
  });

  testWidgets(
    'quick initialization still gives the custom splash time to show',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupGate(
            initialize: () async {
              calls++;
            },
            authGateBuilder: (_) => const Scaffold(body: Text('Destination')),
          ),
        ),
      );

      expect(calls, 1);
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump();
      expect(find.text('Ready to go.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 1799));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('Destination'), findsOneWidget);
      expect(calls, 1);
    },
  );

  testWidgets('Firebase work starts after the splash frame, not during build', (
    tester,
  ) async {
    final initialization = Completer<void>();
    SchedulerPhase? initializationPhase;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          initialize: () {
            initializationPhase = WidgetsBinding.instance.schedulerPhase;
            return initialization.future;
          },
          authGateBuilder: (_) => const Scaffold(body: Text('Destination')),
        ),
      ),
    );

    expect(initializationPhase, SchedulerPhase.idle);
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.byType(SplashScreen), findsOneWidget);
    initialization.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsOneWidget);
  });

  testWidgets('slow initialization exits as soon as it finishes after 1.8s', (
    tester,
  ) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          initialize: () => initialization.future,
          authGateBuilder: (_) => const Scaffold(body: Text('Destination')),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    initialization.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Destination'), findsOneWidget);
  });

  testWidgets('startup failure can retry without constructing AuthGate', (
    tester,
  ) async {
    final first = Completer<void>();
    final second = Completer<void>();
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          initialize: () => ++attempts == 1 ? first.future : second.future,
          authGateBuilder: (_) => const Scaffold(body: Text('Signed in')),
        ),
      ),
    );
    first.completeError(StateError('startup failed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Lakwatsa could not start. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Signed in'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(attempts, 2);

    second.complete();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(find.text('Signed in'), findsOneWidget);
  });

  testWidgets('auth wait shares splash and resolves to the existing gate', (
    tester,
  ) async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: auth.stream,
          authenticatedBuilder: (_) => const Scaffold(body: Text('Home')),
        ),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);

    auth.add(_User());
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('splash fits a compact Android viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('PACK SMART. SCAN EASY.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'branding and progress stay centered on narrow and wide screens',
    (tester) async {
      for (final size in [const Size(320, 568), const Size(430, 932)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        await tester.pump();

        final screenCenter = size.width / 2;
        for (final finder in [
          find.byKey(const Key('splash-mark')),
          find.byKey(const Key('splash-wordmark')),
          find.text('PACK SMART. SCAN EASY.'),
          find.byType(CircularProgressIndicator),
        ]) {
          expect(
            (tester.getCenter(finder).dx - screenCenter).abs(),
            lessThan(4),
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('splash and light-screen system bars use opposite contrast', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
    expect(AppSystemUi.light.statusBarIconBrightness, Brightness.dark);
    expect(
      AppSystemUi.light.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
    expect(AppTheme.light.appBarTheme.systemOverlayStyle, AppSystemUi.light);
  });

  testWidgets('splash fonts load from bundled assets without network', (
    tester,
  ) async {
    final previous = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(() {
      GoogleFonts.config.allowRuntimeFetching = previous;
    });

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.runAsync(() async {
      await GoogleFonts.pendingFonts([
        GoogleFonts.pressStart2p(),
        GoogleFonts.plusJakartaSans(),
      ]);
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('PACK SMART. SCAN EASY.'), findsOneWidget);
  });

  for (final signedIn in [false, true]) {
    testWidgets('startup resolves to ${signedIn ? 'Home' : 'Login'}', (
      tester,
    ) async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      await tester.pumpWidget(
        MaterialApp(
          home: StartupGate(
            initialize: () async {},
            authGateBuilder: (_) => AuthGate(
              authStateChanges: auth.stream,
              authenticatedBuilder: (_) => const Scaffold(body: Text('Home')),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      auth.add(signedIn ? _User() : null);
      await tester.pumpAndSettle();
      if (signedIn) {
        expect(find.text('Home'), findsOneWidget);
      } else {
        expect(find.byType(SignInScreen), findsOneWidget);
      }
    });
  }
}
