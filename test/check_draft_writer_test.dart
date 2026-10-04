import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity_check_draft.dart';
import 'package:lakwatsa/services/check_draft_writer.dart';

void main() {
  test('draft takes an independent immutable snapshot', () {
    final original = {'first': 'MANUAL'};
    final draft = ActivityCheckDraft(
      startedAt: DateTime(2026, 1, 1),
      foundMethods: original,
    );

    original['second'] = 'QR';
    expect(draft.foundMethods, {'first': 'MANUAL'});
    expect(() => draft.foundMethods['third'] = 'MANUAL',
        throwsUnsupportedError);
  });

  test('queued writes preserve order and snapshots', () async {
    final gate = Completer<void>();
    final recorded = <Map<String, String>>[];
    final writer = CheckDraftWriter(
      write: (snapshot) async {
        if (recorded.isEmpty) await gate.future;
        recorded.add(snapshot);
      },
    );

    final selection = {'first': 'MANUAL'};
    writer.save(selection);
    selection['second'] = 'QR';
    writer.save(selection);
    gate.complete();
    await writer.flush();

    expect(recorded, [
      {'first': 'MANUAL'},
      {'first': 'MANUAL', 'second': 'QR'},
    ]);
  });

  test('a failed write does not block the next save', () async {
    var attempts = 0;
    final errors = <Object>[];
    final writer = CheckDraftWriter(
      write: (_) async {
        if (++attempts == 1) throw StateError('temporary failure');
      },
      onError: errors.add,
    );

    writer.save({'first': 'MANUAL'});
    await writer.flush();
    writer.save({'first': 'QR'});
    await writer.flush();
    expect(attempts, 2);
    expect(errors, hasLength(1));
  });
}
