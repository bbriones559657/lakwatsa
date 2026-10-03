// Tests the actual deployed rule language against the OFFICIAL local emulator.
// Run with --dart-define=FIRESTORE_RULES_TEST=true after starting port 8080.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/domain/packing.dart';

const enabled = bool.fromEnvironment('FIRESTORE_RULES_TEST');
const project = 'demo-lakwatsa-rules';

Map<String, dynamic> field(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': '$value'};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(field).toList()},
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': value.map((k, v) => MapEntry(k as String, field(v))),
      },
    };
  }
  throw ArgumentError('Unsupported field $value');
}

String token(String uid) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode({
    'sub': uid,
    'user_id': uid,
    'aud': project,
    'iss': 'https://securetoken.google.com/$project',
    'iat': now,
    'exp': now + 3600,
    'firebase': {'sign_in_provider': 'custom'},
  })}.';
}

void main() {
  late HttpClient client;
  late String id;
  Future<int> request(
    String method,
    String path, {
    String? uid = 'alice',
    Map<String, dynamic>? data,
  }) async {
    final req = await client.openUrl(
      method,
      Uri.parse(
        'http://127.0.0.1:8080/v1/projects/$project/databases/(default)/documents/$path',
      ),
    );
    if (uid != null) req.headers.set('Authorization', 'Bearer ${token(uid)}');
    if (data != null) {
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({'fields': data.map((k, v) => MapEntry(k, field(v)))}),
      );
    }
    final response = await req.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode >= 500) fail(body);
    return response.statusCode;
  }

  group(
    'official Firestore emulator',
    () {
      setUpAll(() async {
        final setupClient = HttpClient();
        try {
          final req = await setupClient.putUrl(
            Uri.parse(
              'http://127.0.0.1:8080/emulator/v1/projects/$project:securityRules',
            ),
          );
          req.headers.contentType = ContentType.json;
          req.write(
            jsonEncode({
              'rules': {
                'files': [
                  {
                    'name': 'firestore.rules',
                    'content': File('firestore.rules').readAsStringSync(),
                  },
                ],
              },
            }),
          );
          final response = await req.close();
          final body = await utf8.decoder.bind(response).join();
          expect(response.statusCode, 200, reason: body);
        } finally {
          setupClient.close(force: true);
        }
      });
      setUp(() {
        client = HttpClient();
        id = 'test-${DateTime.now().microsecondsSinceEpoch}';
      });
      tearDown(() => client.close(force: true));
      test('all supplied legacy paths remain owner-only including nested check items', () async {
        final paths = [
          'users/alice',
          'users/alice/items/$id',
          'users/alice/lists/$id',
          'users/alice/lists/$id/items/member',
          'users/alice/activities/$id',
          'users/alice/activities/$id/items/snapshot',
          'users/alice/activities/$id/checks/before',
          'users/alice/activities/$id/checks/before/items/result',
        ];
        for (final path in paths) {
          expect(
            await request('PATCH', path, data: {'legacy': true}),
            200,
            reason: path,
          );
          expect(await request('GET', path), 200, reason: path);
          expect(await request('GET', path, uid: 'bob'), 403, reason: path);
          expect(await request('GET', path, uid: null), 403, reason: path);
          expect(
            await request('PATCH', path, uid: 'bob', data: {'legacy': false}),
            403,
            reason: path,
          );
          expect(
            await request('PATCH', path, uid: null, data: {'legacy': false}),
            403,
            reason: path,
          );
          expect(await request('DELETE', path, uid: 'bob'), 403, reason: path);
        }
        expect(await request('GET', 'users/alice/items'), 200);
        expect(await request('GET', 'users/alice/items', uid: 'bob'), 403);
        expect(
          await request(
            'GET',
            'users/alice/activities/$id/checks/before/items',
          ),
          200,
        );
        expect(
          await request(
            'GET',
            'users/alice/activities/$id/checks/before/items',
            uid: 'bob',
          ),
          403,
        );
        expect(
          await request(
            'PATCH',
            'users/alice/unexpected/$id',
            data: {'legacy': true},
          ),
          403,
        );
        expect(await request('DELETE', paths.last), 200);
      });
      test('owner CRUD and list queries reject other accounts and anonymous callers', () async {
        final path = 'lakwatsa_v2_users/alice/items/$id';
        final item = Belonging(
          id: id,
          name: 'Keys',
          category: 'Other',
          quantity: 1,
        ).toMap();
        expect(await request('PATCH', path, data: item), 200);
        expect(await request('GET', path), 200);
        expect(await request('GET', path, uid: 'bob'), 403);
        expect(await request('GET', path, uid: null), 403);
        expect(await request('PATCH', path, uid: null, data: item), 403);
        expect(await request('PATCH', path, uid: 'bob', data: item), 403);
        expect(await request('GET', 'lakwatsa_v2_users/alice/items'), 200);
        expect(
          await request('GET', 'lakwatsa_v2_users/alice/items', uid: 'bob'),
          403,
        );
        expect(
          await request('PATCH', path, data: {...item, 'quantity': 0}),
          403,
        );
        expect(await request('DELETE', path), 403);
      });
      test(
        'anonymous creation and unknown collection paths are denied',
        () async {
          final item = Belonging(
            id: id,
            name: 'Keys',
            category: 'Other',
            quantity: 1,
          ).toMap();
          expect(
            await request(
              'PATCH',
              'lakwatsa_v2_users/alice/items/$id',
              uid: null,
              data: item,
            ),
            403,
          );
          expect(
            await request(
              'PATCH',
              'lakwatsa_v2_users/alice/unexpected/$id',
              data: item,
            ),
            403,
          );
          expect(await request('PATCH', 'unexpected/$id', data: item), 403);
          expect(await request('GET', 'unexpected/$id', uid: null), 403);
        },
      );
      test('lists are owner-scoped and deleting a list is allowed only to its owner', () async {
        final path = 'lakwatsa_v2_users/alice/lists/$id';
        final list = PackingList(
          id: id,
          name: 'Daily',
          quantities: {'keys': 1},
        ).toMap();
        expect(await request('PATCH', path, data: list), 200);
        expect(await request('GET', path, uid: 'bob'), 403);
        expect(await request('PATCH', path, uid: 'bob', data: list), 403);
        expect(await request('DELETE', path, uid: 'bob'), 403);
        expect(await request('DELETE', path), 200);
      });
      test('planned to active to complete succeeds and completed history cannot change', () async {
        final path = 'lakwatsa_v2_users/alice/activities/$id';
        final now = DateTime.now().toUtc();
        final data = PackingActivity(
          id: id,
          name: 'Trip',
          type: 'Trip',
          status: ActivityStatus.planned,
          startsAt: now,
          endsAt: now.add(const Duration(hours: 2)),
          reminderMinutes: 30,
          items: {
            'keys': const PackedItem(
              id: 'keys',
              name: 'Keys',
              category: 'Other',
              quantity: 1,
            ),
          },
        ).toMap();
        expect(await request('PATCH', path, data: data), 200);
        expect(await request('GET', path, uid: 'bob'), 403);
        expect(
          await request('PATCH', path, data: {...data, 'status': 'completed'}),
          403,
        );
        expect(
          await request(
            'PATCH',
            path,
            data: {
              ...data,
              'items': {
                'keys': {
                  'name': 'Rewritten',
                  'category': 'Other',
                  'quantity': 1,
                  'addedDuringActivity': false,
                },
              },
            },
          ),
          403,
        );
        final draft = {
          ...data,
          'draft': {'keys': 'qr'},
          'draftStartedAt': now.toIso8601String(),
        };
        expect(await request('PATCH', path, data: draft), 200);
        final before = CheckRecord(
          startedAt: now,
          completedAt: now,
          itemIds: ['keys'],
          found: {'keys': CheckMethod.qr},
        ).toMap();
        final active = {
          ...draft,
          'status': 'active',
          'before': before,
          'draft': <String, dynamic>{},
          'draftStartedAt': null,
        };
        expect(await request('PATCH', path, data: active), 200);
        expect(
          await request(
            'PATCH',
            path,
            data: {
              ...active,
              'before': {...before, 'found': <String, dynamic>{}},
            },
          ),
          403,
        );
        final returned = CheckRecord(
          startedAt: now,
          completedAt: now,
          itemIds: ['keys'],
          found: {},
        ).toMap();
        final complete = {
          ...active,
          'status': 'completed',
          'returned': returned,
        };
        expect(await request('PATCH', path, data: complete), 200);
        expect(
          await request('PATCH', path, data: {...complete, 'name': 'Changed'}),
          403,
        );
        expect(await request('PATCH', path, data: active), 403);
        expect(await request('DELETE', path), 403);
      });
    },
    skip: enabled ? false : 'Start the official local emulator, then enable FIRESTORE_RULES_TEST.',
  );
}
