import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity_status_policy.dart';

void main() {
  test('Activity metadata is editable until completion', () {
    ActivityStatusPolicy.requireMetadataEdit('UPCOMING');
    ActivityStatusPolicy.requireMetadataEdit('ACTIVE');

    for (final status in ['COMPLETED', null]) {
      expect(
        () => ActivityStatusPolicy.requireMetadataEdit(status),
        throwsStateError,
      );
    }
  });
}
