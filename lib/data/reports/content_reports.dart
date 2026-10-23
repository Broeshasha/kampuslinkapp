import '../sync/outbox_repository.dart';

/// Contract 11, B4: what a student can report and why.
const reportTargetTypes = {'card', 'question', 'set', 'lesson', 'block'};
const reportReasons = [
  'wrong_answer',
  'typo',
  'unclear',
  'translation',
  'other',
];

/// "Report a mistake": one outbox op 'content_report' per target (sending
/// again replaces the unsent one; the server keeps one per student and
/// target). Works offline: it leaves with the next sync.
class ContentReports {
  ContentReports(this._outbox);

  static const maxNote = 300;

  final OutboxRepository _outbox;

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    int? lessonId,
    String? note,
  }) {
    if (!reportTargetTypes.contains(targetType)) {
      throw ArgumentError.value(targetType, 'targetType');
    }
    if (!reportReasons.contains(reason)) {
      throw ArgumentError.value(reason, 'reason');
    }
    if (targetType == 'block' && lessonId == null) {
      throw ArgumentError('a block report needs its lesson_id');
    }
    final text = note?.trim() ?? '';
    return _outbox.enqueue('content_report', {
      'target_type': targetType,
      'target_id': targetId,
      'lesson_id': ?lessonId,
      'reason': reason,
      if (text.isNotEmpty)
        'note': text.length > maxNote ? text.substring(0, maxNote) : text,
    }, replaceKey: 'content_report:$targetType:$targetId');
  }
}
