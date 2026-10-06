import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/screens/activities/activity_check_error_text.dart';

void main() {
  test('legacy migration errors are explained without calling them network errors', () {
    final error = StateError(
      'This older Activity needs a secure migration before checking or changing Items.',
    );

    expect(isLegacyActivityMigrationError(error), isTrue);
    expect(
      activityDraftSaveErrorMessage(error),
      contains('one-time secure upgrade'),
    );
    expect(activityDraftSaveErrorMessage(error), isNot(contains('connection')));
  });
}
