import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity_status_policy.dart';

void main() {
  test('New Activities must begin UPCOMING', () {
    ActivityStatusPolicy.requireNew('UPCOMING');
    for (final status in ['ACTIVE', 'COMPLETED', null]) {
      expect(() => ActivityStatusPolicy.requireNew(status), throwsStateError);
    }
  });

  test('Before Check is only valid for UPCOMING', () {
    ActivityStatusPolicy.requireBefore('UPCOMING');
    for (final status in ['ACTIVE', 'COMPLETED', null]) {
      expect(() => ActivityStatusPolicy.requireBefore(status), throwsStateError);
    }
  });

  test('Return Check is only valid for ACTIVE', () {
    ActivityStatusPolicy.requireReturn('ACTIVE');
    for (final status in ['UPCOMING', 'COMPLETED', null]) {
      expect(() => ActivityStatusPolicy.requireReturn(status), throwsStateError);
    }
  });

  test('Before draft must belong to an upcoming Activity', () {
    ActivityStatusPolicy.requireDraft('UPCOMING', 'BEFORE_ACTIVITY');
    expect(
      () => ActivityStatusPolicy.requireDraft('ACTIVE', 'BEFORE_ACTIVITY'),
      throwsStateError,
    );
  });

  test('Return draft must belong to an active Activity', () {
    ActivityStatusPolicy.requireDraft('ACTIVE', 'RETURN');
    expect(
      () => ActivityStatusPolicy.requireDraft('COMPLETED', 'RETURN'),
      throwsStateError,
    );
  });

  test('Unknown draft type is rejected', () {
    expect(
      () => ActivityStatusPolicy.requireDraft('ACTIVE', 'OTHER'),
      throwsArgumentError,
    );
  });

  test('Items can only be added before Activity completion', () {
    ActivityStatusPolicy.requireEditable('UPCOMING');
    ActivityStatusPolicy.requireEditable('ACTIVE');
    for (final status in ['COMPLETED', null]) {
      expect(
        () => ActivityStatusPolicy.requireEditable(status),
        throwsStateError,
      );
    }
  });

  test('Added-during-activity flag follows the Activity status', () {
    expect(ActivityStatusPolicy.addedDuringActivityFor('UPCOMING'), isFalse);
    expect(ActivityStatusPolicy.addedDuringActivityFor('ACTIVE'), isTrue);
    expect(
      () => ActivityStatusPolicy.addedDuringActivityFor('COMPLETED'),
      throwsStateError,
    );
  });

  test('Items can only be removed while the Activity is UPCOMING', () {
    ActivityStatusPolicy.requireItemRemoval('UPCOMING');
    for (final status in ['ACTIVE', 'COMPLETED', null]) {
      expect(
        () => ActivityStatusPolicy.requireItemRemoval(status),
        throwsStateError,
      );
    }
  });
}
