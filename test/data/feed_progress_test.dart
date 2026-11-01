import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/learning/feed_progress.dart';
import 'package:kampuslink/data/learning/feed_queue.dart';

final _now = DateTime(2026, 11, 2, 12);

CardFacts _card(
  int id, {
  int module = 1,
  int chapter = 0,
  bool seen = false,
  bool right = false,
  int box = 1,
  int wrong = 0,
  DateTime? due,
  String? kind,
  int difficulty = 2,
}) => CardFacts(
  key: 'c:$id',
  moduleId: module,
  chapter: chapter,
  lessonId: id,
  position: id,
  cardKind: kind,
  difficulty: difficulty,
  seen: seen,
  rightOnce: right,
  box: box,
  wrongCount: wrong,
  dueAt: due,
);

List<CardFacts> _chapter(int ch, int count, {int seen = 0, int right = 0}) => [
  for (var i = 0; i < count; i++)
    _card(
      ch * 100 + i,
      chapter: ch,
      seen: i < seen,
      right: i < right,
      box: i < right ? 2 : 1,
      due: i < seen ? _now.add(const Duration(days: 1)) : null,
    ),
];

void main() {
  group('frontier', () {
    test('advances at 80% seen AND 60% right, never by reading', () {
      expect(chapterPassed(_chapter(0, 10, seen: 7, right: 7)), isFalse);
      expect(chapterPassed(_chapter(0, 10, seen: 8, right: 5)), isFalse);
      expect(chapterPassed(_chapter(0, 10, seen: 8, right: 6)), isTrue);
      final cards = [
        ..._chapter(0, 10, seen: 10, right: 9),
        ..._chapter(1, 10, seen: 3, right: 3),
        ..._chapter(2, 10),
      ];
      expect(computeFrontiers(cards), {1: 1});
      // Never back below what was stored; never beyond the last chapter.
      expect(computeFrontiers(cards, stored: {1: 2}), {1: 2});
      expect(computeFrontiers(cards, stored: {1: 9}), {1: 2});
    });

    test('new cards: frontier first (definitions, easy), then +1, '
        'nothing beyond', () {
      final cards = [
        _card(1, kind: 'formula', difficulty: 1),
        _card(2, kind: 'definition', difficulty: 3),
        _card(3, kind: 'definition', difficulty: 1),
        _card(4, chapter: 1, kind: 'definition', difficulty: 1),
        _card(5, chapter: 2, kind: 'definition', difficulty: 1),
      ];
      final b = progressBuckets(cards, frontiers: {1: 0}, now: _now);
      expect(b.fresh.map((i) => i.key), ['c:3', 'c:2', 'c:1', 'c:4']);
      expect(b.review, isEmpty);
    });
  });

  test('70/30 mix of frontier and review cards over 200 posts', () {
    final pool = {
      FeedBucket.known: <FeedItem>[],
      FeedBucket.fresh: [
        for (var i = 0; i < 300; i++)
          FeedItem(
            key: 'n:$i',
            bucket: FeedBucket.fresh,
            lessonId: i,
            order: i,
          ),
      ],
      FeedBucket.due: [
        for (var i = 0; i < 300; i++)
          FeedItem(key: 'r:$i', bucket: FeedBucket.due, lessonId: 1000 + i),
      ],
      FeedBucket.set: [
        for (var i = 0; i < 40; i++)
          FeedItem(key: 's:$i', bucket: FeedBucket.set, order: i),
      ],
      FeedBucket.quick: [
        for (var i = 0; i < 40; i++)
          FeedItem(key: 'q:$i', bucket: FeedBucket.quick, lessonId: 2000 + i),
      ],
    };
    for (var seed = 0; seed < 5; seed++) {
      final q = buildFeedQueue(
        pool: pool,
        random: math.Random(seed),
        now: _now,
        size: 200,
        shares: progressFeedShares,
        repeat: false,
        proportionalFill: true,
      );
      final fresh = q.where((i) => i.bucket == FeedBucket.fresh).length;
      final review = q.where((i) => i.bucket == FeedBucket.due).length;
      final share = fresh / (fresh + review);
      expect(share, inInclusiveRange(0.62, 0.78), reason: 'seed $seed: $share');
    }
  });

  test('no post twice in one session (batches, excluded keys)', () {
    final pool = {
      FeedBucket.fresh: [
        for (var i = 0; i < 30; i++)
          FeedItem(
            key: 'n:$i',
            bucket: FeedBucket.fresh,
            lessonId: i,
            order: i,
          ),
      ],
      FeedBucket.due: [
        for (var i = 0; i < 10; i++)
          FeedItem(key: 'r:$i', bucket: FeedBucket.due, lessonId: 100 + i),
      ],
    };
    List<FeedItem> batch(List<FeedItem> before, Set<String> exclude) =>
        buildFeedQueue(
          pool: pool,
          random: math.Random(1),
          now: _now,
          size: 25,
          before: before,
          exclude: exclude,
          shares: progressFeedShares,
          repeat: false,
          proportionalFill: true,
        );
    final first = batch(const [], {'n:0', 'r:0'});
    final second = batch(first, {'n:0', 'r:0'});
    final keys = [...first, ...second].map((i) => i.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(keys, isNot(contains('n:0')));
    expect(keys.length, 38); // 40 posts minus the 2 excluded, then it ends
  });

  test('review prefers failed and due cards', () {
    final cards = [
      for (var i = 0; i < 50; i++)
        _card(
          i,
          seen: true,
          box: 1,
          wrong: 2,
          due: _now.subtract(const Duration(days: 2)),
        ),
      for (var i = 50; i < 100; i++)
        _card(i, seen: true, right: true, box: 4, due: _now),
    ];
    final b = progressBuckets(cards, frontiers: {1: 1}, now: _now);
    expect(b.review, hasLength(100));
    var failed = 0;
    for (var seed = 0; seed < 10; seed++) {
      final q = buildFeedQueue(
        pool: {FeedBucket.due: b.review},
        random: math.Random(seed),
        now: _now,
        size: 30,
        shares: progressFeedShares,
        repeat: false,
        proportionalFill: true,
      );
      failed += q.where((i) => int.parse(i.key.substring(2)) < 50).length;
    }
    expect(failed / 300, greaterThan(0.6));
    // A card answered right and not due does not come back.
    final later = progressBuckets(
      [
        _card(
          1,
          seen: true,
          right: true,
          box: 3,
          due: _now.add(const Duration(days: 3)),
        ),
      ],
      frontiers: {1: 1},
      now: _now,
    );
    expect(later.review, isEmpty);
  });

  test('chip filter keeps only that module', () {
    final pool = {
      FeedBucket.fresh: [
        const FeedItem(key: 'a', bucket: FeedBucket.fresh, moduleId: 1),
        const FeedItem(key: 'b', bucket: FeedBucket.fresh, moduleId: 2),
      ],
      FeedBucket.set: [const FeedItem(key: 's', bucket: FeedBucket.set)],
    };
    expect(filterPool(pool, null), same(pool));
    final only2 = filterPool(pool, 2);
    expect(only2[FeedBucket.fresh]!.map((i) => i.key), ['b']);
    expect(only2[FeedBucket.set], isEmpty);
  });

  test('report: share of chapter-1 cards in the first 100 posts', () {
    // 1 module, 5 chapters x 2 lessons x 10 cards; the student only
    // scrolls Home, never reads, answers every card right.
    final state = <String, ({bool seen, int box, DateTime? due})>{};
    int chapterOf(String key) => int.parse(key.substring(2)) ~/ 100;
    CardFacts fact(int ch, int i) {
      final key = 'c:${ch * 100 + i}';
      final s = state[key];
      return CardFacts(
        key: key,
        moduleId: 1,
        chapter: ch,
        lessonId: ch * 2 + i ~/ 10,
        lessonPosition: ch * 2 + i ~/ 10,
        position: i,
        seen: s?.seen ?? false,
        rightOnce: s?.seen ?? false,
        box: s?.box ?? 1,
        dueAt: s?.due,
      );
    }

    List<CardFacts> facts() => [
      for (var ch = 0; ch < 5; ch++)
        for (var i = 0; i < 20; i++) fact(ch, i),
    ];
    void answer(FeedItem i) => state[i.key] = (
      seen: true,
      box: 2,
      due: _now.add(const Duration(days: 1)),
    );

    double run({required bool progressive}) {
      state.clear();
      final shown = <FeedItem>[];
      var stored = <int, int>{};
      for (var round = 0; round < 8 && shown.length < 100; round++) {
        final f = facts();
        final Map<FeedBucket, List<FeedItem>> pool;
        if (progressive) {
          stored = computeFrontiers(f, stored: stored);
          final b = progressBuckets(f, frontiers: stored, now: _now);
          pool = {FeedBucket.fresh: b.fresh, FeedBucket.due: b.review};
        } else {
          // Before: new cards only from the current lesson + the next one
          // (lessons 0 and 1 when nothing is read), known/due as before.
          pool = {
            FeedBucket.fresh: [
              for (final c in f)
                if (!c.seen && (c.lessonId ?? 9) <= 1)
                  FeedItem(
                    key: c.key,
                    bucket: FeedBucket.fresh,
                    order: c.position,
                  ),
            ],
            FeedBucket.due: [
              for (final c in f)
                if (c.seen && c.box < 3 && !c.dueAt!.isAfter(_now))
                  FeedItem(key: c.key, bucket: FeedBucket.due),
            ],
          };
        }
        final q = progressive
            ? buildFeedQueue(
                pool: pool,
                random: math.Random(round),
                now: _now,
                size: 25,
                before: shown,
                shares: progressFeedShares,
                repeat: false,
                proportionalFill: true,
              )
            : buildFeedQueue(
                pool: pool,
                random: math.Random(round),
                now: _now,
                size: 25,
                before: shown,
              );
        if (q.isEmpty) break;
        for (final i in q.take(100 - shown.length)) {
          shown.add(i);
          answer(i);
        }
      }
      final ch1 = shown.where((i) => chapterOf(i.key) == 0).length;
      debugPrint(
        '${progressive ? 'AFTER ' : 'BEFORE'}: ${shown.length} posts, '
        '${(100 * ch1 / shown.length).round()}% from chapter 1, '
        'chapters reached: ${shown.map((i) => chapterOf(i.key) + 1).toSet()}',
      );
      return ch1 / shown.length;
    }

    expect(run(progressive: false), greaterThan(0.9));
    expect(run(progressive: true), lessThan(0.4));
  });
}
