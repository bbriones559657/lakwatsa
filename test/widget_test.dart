import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lakwatsa/main.dart';

void main() {
  testWidgets(
    'configuration failure is visible rather than an endless splash',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(
        const LakwatsaApp(startupError: 'Configuration required'),
      );
      expect(find.text('Configuration required'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
