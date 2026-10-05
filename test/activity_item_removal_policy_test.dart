import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity_status_policy.dart';

void main() {
  test('Activity must keep at least one Item', () {
    ActivityStatusPolicy.requireItemCountForRemoval(2);

    expect(
      () => ActivityStatusPolicy.requireItemCountForRemoval(1),
      throwsStateError,
    );
    expect(
      () => ActivityStatusPolicy.requireItemCountForRemoval(0),
      throwsStateError,
    );
  });
}
