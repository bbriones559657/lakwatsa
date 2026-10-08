import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/widgets/lakwatsa_ui.dart';

void main() {
  testWidgets('header action keeps a minimum 44px touch target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LakwatsaHeaderAction(
            text: '+',
            label: 'Add item',
            filled: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(LakwatsaHeaderAction));

    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('search field keeps shared copy and forwards changes', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    String latestValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LakwatsaSearchField(
            controller: controller,
            hintText: 'Search items...',
            onChanged: (value) {
              latestValue = value;
            },
          ),
        ),
      ),
    );

    expect(find.text('Search items...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'charger');

    expect(latestValue, 'charger');
  });
}
