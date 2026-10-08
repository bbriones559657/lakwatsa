import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/screens/auth/auth_gate.dart';
import 'package:lakwatsa/screens/auth/sign_in_screen.dart';

class _User extends Fake implements User {
  @override
  final String uid;
  _User(this.uid);
}

void main() {
  testWidgets(
    'sign out removes protected routes and dialogs from Back history',
    (tester) async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: AuthGate(
            authStateChanges: auth.stream,
            authenticatedBuilder: (_) => const Scaffold(body: Text('Home')),
          ),
        ),
      );
      auth.add(_User('first'));
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const PopScope(
            canPop: false,
            child: Scaffold(body: Text('Private activity')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      showDialog<void>(
        context: tester.element(find.text('Private activity')),
        builder: (_) => const AlertDialog(content: Text('Private dialog')),
      );
      await tester.pumpAndSettle();
      auth.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Private activity'), findsNothing);
      expect(find.text('Private dialog'), findsNothing);
      expect(navigator.currentState!.canPop(), isFalse);
      auth.add(_User('second'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'direct account switch replaces session state and duplicate events keep routes',
    (tester) async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      final navigator = GlobalKey<NavigatorState>();
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: AuthGate(
            authStateChanges: auth.stream,
            authenticatedBuilder: (_) => _Session(onCreate: () => created++),
          ),
        ),
      );
      auth.add(_User('first'));
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private activity')),
        ),
      );
      await tester.pumpAndSettle();
      auth.add(_User('first'));
      await tester.pumpAndSettle();
      expect(find.text('Private activity'), findsOneWidget);
      expect(created, 1);
      auth.add(_User('second'));
      await tester.pumpAndSettle();
      expect(find.text('Private activity'), findsNothing);
      expect(created, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Session extends StatefulWidget {
  final VoidCallback onCreate;
  const _Session({required this.onCreate});
  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Home'));
}
