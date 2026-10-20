/// BACKEND_CONTRACT D: 'ar' when the text is mostly Arabic letters, else
/// 'und' (the translation worker corrects it).
String guessLang(String text) {
  var arabic = 0;
  var latin = 0;
  for (final r in text.runes) {
    if (r >= 0x0600 && r <= 0x06FF) {
      arabic++;
    } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
      latin++;
    }
  }
  return arabic > latin ? 'ar' : 'und';
}

/// One message from get_chat_messages (also how it is cached).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.body,
    required this.lang,
    required this.createdAt,
    required this.isMine,
    this.translatedBody,
    this.translatedLang,
    this.replyTo,
  });

  factory ChatMessage.fromRow(Map<String, dynamic> r) => ChatMessage(
    id: '${r['id']}',
    userId: '${r['user_id'] ?? ''}',
    username: '${r['username'] ?? ''}',
    body: '${r['body'] ?? ''}',
    lang: '${r['lang'] ?? 'und'}',
    translatedBody: r['translated_body']?.toString(),
    translatedLang: r['translated_lang']?.toString(),
    replyTo: r['reply_to']?.toString(),
    createdAt:
        DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime(2000),
    isMine: r['is_mine'] == true,
  );

  final String id;
  final String userId;
  final String username;
  final String body;
  final String lang;
  final String? translatedBody;
  final String? translatedLang;
  final String? replyTo;
  final DateTime createdAt;
  final bool isMine;

  Map<String, dynamic> toRow() => {
    'id': id,
    'user_id': userId,
    'username': username,
    'body': body,
    'lang': lang,
    'translated_body': translatedBody,
    'translated_lang': translatedLang,
    'reply_to': replyTo,
    'created_at': createdAt.toUtc().toIso8601String(),
    'is_mine': isMine,
  };

  ChatMessage withTranslation(String body, String lang) => ChatMessage(
    id: id,
    userId: userId,
    username: username,
    body: this.body,
    lang: this.lang,
    translatedBody: body,
    translatedLang: lang,
    replyTo: replyTo,
    createdAt: createdAt,
    isMine: isMine,
  );
}

/// A message typed on this phone and not yet confirmed by the server.
/// [clientId] makes a retry safe (the server stores it once).
class PendingMessage {
  const PendingMessage({
    required this.clientId,
    required this.body,
    required this.lang,
    required this.createdAt,
    this.attempts = 0,
    this.failed = false,
  });

  factory PendingMessage.fromJson(Map<String, dynamic> j) => PendingMessage(
    clientId: '${j['client_id']}',
    body: '${j['body'] ?? ''}',
    lang: '${j['lang'] ?? 'und'}',
    createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime(2000),
    attempts: j['attempts'] is num ? (j['attempts'] as num).toInt() : 0,
    failed: j['failed'] == true,
  );

  final String clientId;
  final String body;
  final String lang;
  final DateTime createdAt;
  final int attempts;

  /// true after 3 failed tries: the student taps to retry.
  final bool failed;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'body': body,
    'lang': lang,
    'created_at': createdAt.toIso8601String(),
    'attempts': attempts,
    'failed': failed,
  };

  PendingMessage copyWith({int? attempts, bool? failed}) => PendingMessage(
    clientId: clientId,
    body: body,
    lang: lang,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    failed: failed ?? this.failed,
  );
}
