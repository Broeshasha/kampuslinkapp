import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/chat/chat_models.dart';
import 'package:kampuslink/data/chat/chat_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';

Map<String, dynamic> row(String id, int minute, {String user = 'u2'}) => {
  'id': id,
  'user_id': user,
  'username': 'amina',
  'body': 'message $id',
  'lang': 'fr',
  'translated_body': null,
  'translated_lang': null,
  'created_at': DateTime.utc(2026, 10, 20, 10, minute).toIso8601String(),
  'is_mine': user == 'me',
};

void main() {
  late AppDatabase db;
  late List<Map<String, dynamic>> server;
  late List<String> posted;
  Object? postError;

  ChatRepository repo() => ChatRepository(
    db,
    fetch: (moduleId, before) async => [
      for (final r in server)
        if (before == null ||
            DateTime.parse('${r['created_at']}').isBefore(before))
          r,
    ],
    post: (moduleId, body, lang, clientId) async {
      final error = postError;
      if (error != null) throw error;
      posted.add(clientId);
      return {'message_id': 'srv-$clientId', 'duplicate': false};
    },
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = [row('m2', 2), row('m1', 1)];
    posted = [];
    postError = null;
  });

  tearDown(() => db.close());

  test('messages are cached, newest first, and readable offline', () async {
    final list = await repo().refresh(7);
    expect(list.map((m) => m.id), ['m2', 'm1']);
    postError = TimeoutException('offline');
    final offline = await repo().cached(7);
    expect(offline.map((m) => m.id), ['m2', 'm1']);
  });

  test('offline message waits as sending, then goes once online', () async {
    final r = repo();
    postError = TimeoutException('offline');
    await r.queue(7, '  salam  ');
    var report = await r.sendPending(7);
    expect(report.sent, 0);
    final waiting = await r.pending(7);
    expect(waiting.single.body, 'salam');
    expect(waiting.single.failed, isFalse);
    expect(waiting.single.attempts, 0);
    postError = null;
    report = await r.sendPending(7);
    expect(report.sent, 1);
    expect(posted, [waiting.single.clientId]);
    expect(await r.pending(7), isEmpty);
  });

  test('after 3 failed tries: tap to retry, same client id', () async {
    final r = repo();
    postError = Exception('server down');
    final p = await r.queue(7, 'hello');
    for (var i = 0; i < 3; i++) {
      await r.sendPending(7);
    }
    expect((await r.pending(7)).single.failed, isTrue);
    await r.sendPending(7);
    expect(posted, isEmpty, reason: 'a failed message waits for the tap');
    postError = null;
    await r.retry(7, p.clientId);
    await r.sendPending(7);
    expect(posted, [p.clientId]);
  });

  test('older pages, deletions, blocks and translations', () async {
    final r = repo();
    server = [row('m3', 3)];
    await r.refresh(7);
    server = [row('m3', 3), row('m2', 2, user: 'u9'), row('m1', 1)];
    expect(await r.loadOlder(7), 2);
    expect((await r.cached(7)).map((m) => m.id), ['m3', 'm2', 'm1']);
    expect(await r.applyTranslation(7, 'm1', 'ar', 'AR text'), isTrue);
    expect((await r.cached(7)).last.translatedBody, 'AR text');
    await r.removeMessage(7, 'm3');
    await r.removeUser(7, 'u9');
    expect((await r.cached(7)).map((m) => m.id), ['m1']);
  });

  test('language guess: mostly Arabic letters -> ar, else und', () {
    expect(
      guessLang(
        '\u0627\u0644\u0633\u0644\u0627\u0645 \u0639\u0644\u064a\u0643\u0645 ok',
      ),
      'ar',
    );
    expect(guessLang('Bonjour tout le monde'), 'und');
    expect(guessLang('123 !!'), 'und');
  });
}
