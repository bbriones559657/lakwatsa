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

  test('Check Item snapshot must match current Activity Item state', () {
    ActivityStatusPolicy.requireItemSnapshotForCheck(
      currentCount: 3,
      currentRevision: 4,
      submittedCount: 3,
      expectedRevision: 4,
    );

    expect(
      () => ActivityStatusPolicy.requireItemSnapshotForCheck(
        currentCount: 4,
        currentRevision: 4,
        submittedCount: 3,
        expectedRevision: 4,
      ),
      throwsStateError,
    );
    expect(
      () => ActivityStatusPolicy.requireItemSnapshotForCheck(
        currentCount: 3,
        currentRevision: 5,
        submittedCount: 3,
        expectedRevision: 4,
      ),
      throwsStateError,
    );
  });
}
