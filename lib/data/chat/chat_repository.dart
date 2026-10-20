import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/logging/logger.dart';
import '../db/app_database.dart';
import 'chat_models.dart';

typedef FetchChat = Future<List<Map<String, dynamic>>> Function(
  int moduleId,
  DateTime? before,
);
typedef PostChat = Future<Map<String, dynamic>> Function(
  int moduleId,
  String body,
  String lang,
  String clientId,
);

class SendReport {
  const SendReport({this.sent = 0, this.failure});

  final int sent;

  /// The reason sending stopped (offline, rate limited...), if any.
  final AppFailure? failure;
}

/// Module chat, offline-friendly (MASTER_PLAN 7.8): the last messages are
/// cached on the phone (readable offline); a message typed offline waits
/// as "sending..." with its client_id; after 3 failed tries it becomes
/// "tap to retry". Stored in key_values (no schema change).
class ChatRepository {
  ChatRepository(
    this._db, {
    required this.fetch,
    required this.post,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  static const keep = 300;
  static const maxAttempts = 3;

  final AppDatabase _db;
  final FetchChat fetch;
  final PostChat post;
  final DateTime Function() _now;
  final Uuid _uuid;

  String _cacheKey(int m) => 'chat:$m';
  String _pendingKey(int m) => 'chat_pending:$m';

  Future<String?> _get(String key) async => (await (_db.select(
    _db.keyValues,
  )..where((t) => t.name.equals(key))).getSingleOrNull())?.value;

  Future<void> _set(String key, String value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion(name: Value(key), value: Value(value)),
      );

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null) return const [];
    try {
      final v = jsonDecode(raw);
      return v is List
          ? [
              for (final e in v)
                if (e is Map) e.cast<String, dynamic>(),
            ]
          : const [];
    } on FormatException {
      return const [];
    }
  }

  /// Cached messages, newest first.
  Future<List<ChatMessage>> cached(int moduleId) async => [
    for (final r in _decodeList(await _get(_cacheKey(moduleId))))
      ChatMessage.fromRow(r),
  ];

  Future<List<ChatMessage>> _merge(
    int moduleId,
    Iterable<ChatMessage> incoming, {
    int? limit,
  }) async {
    final byId = {for (final m in await cached(moduleId)) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final kept = list.take(limit ?? keep).toList();
    await _set(
      _cacheKey(moduleId),
      jsonEncode([for (final m in kept) m.toRow()]),
    );
    return kept;
  }

  /// Newest page from the server, merged into the cache. Throws when
  /// offline: the caller keeps showing the cache.
  Future<List<ChatMessage>> refresh(int moduleId) async {
    final rows = await fetch(moduleId, null);
    return _merge(moduleId, rows.map(ChatMessage.fromRow));
  }

  /// Older page (scrolling up). Returns how many new messages came in.
  Future<int> loadOlder(int moduleId) async {
    final current = await cached(moduleId);
    if (current.isEmpty) return 0;
    final rows = await fetch(moduleId, current.last.createdAt);
    await _merge(
      moduleId,
      rows.map(ChatMessage.fromRow),
      limit: current.length + rows.length,
    );
    return rows.length;
  }

  Future<void> removeMessage(int moduleId, String id) async {
    final list = (await cached(moduleId)).where((m) => m.id != id).toList();
    await _set(
      _cacheKey(moduleId),
      jsonEncode([for (final m in list) m.toRow()]),
    );
  }

  Future<void> removeUser(int moduleId, String userId) async {
    final list = (await cached(moduleId))
        .where((m) => m.userId != userId)
        .toList();
    await _set(
      _cacheKey(moduleId),
      jsonEncode([for (final m in list) m.toRow()]),
    );
  }

  /// A translation arrived by realtime: true when it was for a cached message.
  Future<bool> applyTranslation(
    int moduleId,
    String messageId,
    String lang,
    String body,
  ) async {
    final list = await cached(moduleId);
    final i = list.indexWhere((m) => m.id == messageId);
    if (i < 0) return false;
    list[i] = list[i].withTranslation(body, lang);
    await _set(
      _cacheKey(moduleId),
      jsonEncode([for (final m in list) m.toRow()]),
    );
    return true;
  }

  /// Messages waiting to be sent, oldest first.
  Future<List<PendingMessage>> pending(int moduleId) async => [
    for (final j in _decodeList(await _get(_pendingKey(moduleId))))
      PendingMessage.fromJson(j),
  ];

  Future<void> _savePending(int moduleId, List<PendingMessage> list) => _set(
    _pendingKey(moduleId),
    jsonEncode([for (final p in list) p.toJson()]),
  );

  /// Puts a typed message in the queue (always works, even offline).
  Future<PendingMessage> queue(int moduleId, String body) async {
    final text = body.trim();
    final message = PendingMessage(
      clientId: _uuid.v4(),
      body: text.length > 4000 ? text.substring(0, 4000) : text,
      lang: guessLang(text),
      createdAt: _now(),
    );
    await _savePending(moduleId, [...await pending(moduleId), message]);
    return message;
  }

  Future<void> retry(int moduleId, String clientId) async {
    await _savePending(moduleId, [
      for (final p in await pending(moduleId))
        p.clientId == clientId ? p.copyWith(attempts: 0, failed: false) : p,
    ]);
  }

  Future<void> discard(int moduleId, String clientId) async {
    await _savePending(moduleId, [
      for (final p in await pending(moduleId))
        if (p.clientId != clientId) p,
    ]);
  }

  /// Sends the queue in order. Offline / rate limited: stop and keep all.
  /// Other errors: +1 try; after 3 the message waits for "tap to retry".
  Future<SendReport> sendPending(int moduleId) async {
    var list = await pending(moduleId);
    var sent = 0;
    AppFailure? stop;
    for (final p in list.toList()) {
      if (p.failed) continue;
      try {
        await post(moduleId, p.body, p.lang, p.clientId);
        list = [
          for (final q in list)
            if (q.clientId != p.clientId) q,
        ];
        sent++;
      } catch (error, stack) {
        final failure = mapError(error);
        if (failure is OfflineFailure || failure is RateLimitedFailure) {
          stop = failure;
          break;
        }
        if (failure is ValidationFailure) {
          // e.g. empty_message: it can never be sent.
          list = [
            for (final q in list)
              if (q.clientId != p.clientId) q,
          ];
          continue;
        }
        appLog.error(error, stack, reason: 'chat send');
        final attempts = p.attempts + 1;
        list = [
          for (final q in list)
            q.clientId == p.clientId
                ? q.copyWith(
                    attempts: attempts,
                    failed: attempts >= maxAttempts,
                  )
                : q,
        ];
        stop ??= failure;
      }
    }
    await _savePending(moduleId, list);
    return SendReport(sent: sent, failure: stop);
  }
}
