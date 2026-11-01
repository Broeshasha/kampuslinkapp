import 'feed_queue.dart';

/// A chapter is passed when this share of its cards was seen...
// TODO(app_config): read feed_advance_seen from app_config.
const frontierSeenShare = 0.8;

/// ...and this share was answered right at least once.
// TODO(app_config): read feed_advance_right from app_config.
const frontierRightShare = 0.6;

/// Share of the CARD slots that go to new cards of the frontier; the rest
/// is review of cards already seen.
const frontierCardShare = 0.7;

/// Bucket shares of the progressive feed: cards 82% (70% new from the
/// frontier, 30% review), sets 12%, quick questions 6%. "Known" is not used:
/// a card answered right only comes back when it is due.
const progressFeedShares = <FeedBucket, double>{
  FeedBucket.known: 0,
  FeedBucket.due: 0.82 * (1 - frontierCardShare),
  FeedBucket.fresh: 0.82 * frontierCardShare,
  FeedBucket.set: 0.12,
  FeedBucket.quick: 0.06,
};

/// Everything the feed needs to know about one card (pure data, testable).
class CardFacts {
  const CardFacts({
    required this.key,
    required this.moduleId,
    required this.chapter,
    this.lessonId,
    this.lessonPosition = 0,
    this.position = 0,
    this.cardKind,
    this.difficulty = 2,
    this.concept,
    this.box = 1,
    this.seen = false,
    this.rightOnce = false,
    this.wrongCount = 0,
    this.dueAt,
    this.lastSeen,
    this.lessonRead = false,
    this.payload,
  });

  final String key;
  final int moduleId;

  /// 0-based chapter (unit) index inside the module, in lesson order.
  final int chapter;
  final int? lessonId;
  final int lessonPosition;
  final int position;
  final String? cardKind;
  final int difficulty;
  final String? concept;
  final int box;
  final bool seen;
  final bool rightOnce;
  final int wrongCount;
  final DateTime? dueAt;
  final DateTime? lastSeen;
  final bool lessonRead;
  final Object? payload;
}

const _kindRank = {
  'definition': 0,
  'why': 1,
  'when': 2,
  'trap': 3,
  'formula': 4,
};

/// True when [cards] (one chapter) are seen and known enough to move on.
/// Reading the lesson is never required.
bool chapterPassed(List<CardFacts> cards) {
  if (cards.isEmpty) return true;
  final seen = cards.where((c) => c.seen).length;
  final right = cards.where((c) => c.rightOnce).length;
  return seen >= frontierSeenShare * cards.length - 1e-9 &&
      right >= frontierRightShare * cards.length - 1e-9;
}

/// Frontier chapter per module: the first chapter not passed yet (the
/// last chapter when all are passed). It never goes back below [stored].
Map<int, int> computeFrontiers(
  List<CardFacts> cards, {
  Map<int, int> stored = const {},
}) {
  final byModule = <int, Map<int, List<CardFacts>>>{};
  for (final c in cards) {
    byModule
        .putIfAbsent(c.moduleId, () => {})
        .putIfAbsent(c.chapter, () => [])
        .add(c);
  }
  final out = <int, int>{};
  byModule.forEach((module, chapters) {
    final order = chapters.keys.toList()..sort();
    var frontier = order.last;
    for (final ch in order) {
      if (!chapterPassed(chapters[ch]!)) {
        frontier = ch;
        break;
      }
    }
    final s = stored[module];
    if (s != null && s > frontier) {
      frontier = s > order.last ? order.last : s;
    }
    out[module] = frontier;
  });
  return out;
}

/// How much a seen card needs review: wrong answers, low box, due for a
/// long time, not seen for a long time.
double reviewWeight(CardFacts c, DateTime now) {
  var w = 1.0;
  w += 2.0 * (c.wrongCount > 3 ? 3 : c.wrongCount);
  if (c.box <= 1) {
    w += 1.5;
  } else if (c.box == 2) {
    w += 0.75;
  }
  final due = c.dueAt;
  if (due != null && !due.isAfter(now)) {
    final days = now.difference(due).inHours / 24.0;
    w += 1 + (days > 3 ? 3 : days);
  }
  final last = c.lastSeen;
  if (last != null) {
    final weeks = now.difference(last).inDays / 7.0;
    w += weeks > 2 ? 2 : weeks;
  }
  return w;
}

FeedItem _item(
  CardFacts c,
  FeedBucket bucket, {
  int order = 0,
  double weight = 1,
}) => FeedItem(
  key: c.key,
  bucket: bucket,
  concept: c.concept,
  lessonId: c.lessonId,
  cardKind: c.cardKind,
  difficulty: c.difficulty,
  order: order,
  moduleId: c.moduleId,
  weight: weight,
  learn: !c.lessonRead,
  payload: c.payload,
);

int _compareNew(CardFacts a, CardFacts b) {
  for (final d in [
    (_kindRank[a.cardKind] ?? 2).compareTo(_kindRank[b.cardKind] ?? 2),
    a.difficulty.compareTo(b.difficulty),
    a.lessonPosition.compareTo(b.lessonPosition),
    a.position.compareTo(b.position),
  ]) {
    if (d != 0) return d;
  }
  return a.key.compareTo(b.key);
}

/// The card buckets of the progressive feed:
/// * fresh (N): new cards of the frontier chapter (definition / why first,
///   easy first, lesson order), then of frontier + 1; modules interleaved;
/// * due (review): seen cards that are due (any earlier chapter or the
///   frontier, weighted by [reviewWeight]) and earlier cards never seen.
///   [ahead] = "practise ahead": cards not due yet too (box 1-2).
/// Nothing beyond frontier + 1.
({List<FeedItem> fresh, List<FeedItem> review}) progressBuckets(
  List<CardFacts> cards, {
  required Map<int, int> frontiers,
  required DateTime now,
  bool ahead = false,
}) {
  final newCards = <(int stage, int module), List<CardFacts>>{};
  final review = <FeedItem>[];
  for (final c in cards) {
    final f = frontiers[c.moduleId] ?? 0;
    if (c.chapter > f + 1) continue;
    if (!c.seen) {
      if (c.chapter >= f) {
        newCards.putIfAbsent((c.chapter - f, c.moduleId), () => []).add(c);
      } else {
        review.add(_item(c, FeedBucket.due, weight: 1.5));
      }
      continue;
    }
    final due = c.dueAt == null || !c.dueAt!.isAfter(now);
    if (ahead ? c.box >= 3 : !due) continue;
    final w = reviewWeight(c, now) * (c.chapter >= f ? 0.7 : 1.0);
    review.add(_item(c, FeedBucket.due, weight: w));
  }
  final ranked = <(int stage, int index, int module, CardFacts card)>[];
  newCards.forEach((k, list) {
    list.sort(_compareNew);
    for (var i = 0; i < list.length; i++) {
      ranked.add((k.$1, i, k.$2, list[i]));
    }
  });
  ranked.sort((a, b) {
    for (final d in [
      a.$1.compareTo(b.$1),
      a.$2.compareTo(b.$2),
      a.$3.compareTo(b.$3),
    ]) {
      if (d != 0) return d;
    }
    return 0;
  });
  return (
    fresh: [
      for (var i = 0; i < ranked.length; i++)
        _item(ranked[i].$4, FeedBucket.fresh, order: i),
    ],
    review: review,
  );
}

/// Only the posts of [module] (null = All). [moduleOf] reads an item's
/// module (FeedItem.moduleId by default).
Map<FeedBucket, List<FeedItem>> filterPool(
  Map<FeedBucket, List<FeedItem>> pool,
  int? module, {
  int? Function(FeedItem item)? moduleOf,
}) {
  if (module == null) return pool;
  final of = moduleOf ?? ((FeedItem i) => i.moduleId);
  return {
    for (final e in pool.entries)
      e.key: [
        for (final i in e.value)
          if (of(i) == module) i,
      ],
  };
}
