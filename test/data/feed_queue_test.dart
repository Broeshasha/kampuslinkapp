import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/learning/feed_queue.dart';

const _kinds = ['definition', 'why', 'when', 'trap', 'formula'];

/// 200 cards in 20 lessons (half known, 2 in 10 due, 3 in 10 new but only
/// the first 4 lessons open), 20 sets, 40 quick questions.
Map<FeedBucket, List<FeedItem>> deck({bool newStudent = false}) {
  final pool = {for (final b in FeedBucket.values) b: <FeedItem>[]};
  for (var l = 0; l < 20; l++) {
    for (var c = 0; c < 10; c++) {
      final id = l * 10 + c;
      final bucket = newStudent
          ? FeedBucket.fresh
          : c < 5
          ? FeedBucket.known
          : c < 7
          ? FeedBucket.due
          : FeedBucket.fresh;
      if (bucket == FeedBucket.fresh && l > 3) continue;
      pool[bucket]!.add(
        FeedItem(
          key: 'c:$id',
          bucket: bucket,
          concept: 'l$l:c${c % 4}',
          lessonId: l,
          cardKind: _kinds[c % 5],
          order: id,
        ),
      );
    }
  }
  for (var s = 0; s < 20; s++) {
    pool[FeedBucket.set]!.add(
      FeedItem(key: 's:$s', bucket: FeedBucket.set, lessonId: s, order: s),
    );
  }
  if (!newStudent) {
    for (var q = 0; q < 40; q++) {
      pool[FeedBucket.quick]!.add(
        FeedItem(
          key: 'q:$q',
          bucket: FeedBucket.quick,
          concept: 'l${q % 20}:c${q % 4}',
          lessonId: q % 20,
          order: q,
        ),
      );
    }
  }
  return pool;
}

void expectSpread(List<FeedItem> list) {
  for (var i = 0; i < list.length; i++) {
    final window = list.sublist(math.max(0, i - 39), i).map((e) => e.key);
    expect(window, isNot(contains(list[i].key)), reason: 'repeat at $i');
    if (i >= 1 && list[i].concept != null) {
      expect(list[i].concept, isNot(list[i - 1].concept), reason: 'at $i');
    }
    if (i >= 2 && list[i].bucket != FeedBucket.set) {
      final l = list[i].lessonId;
      final same =
          l != null && list[i - 1].lessonId == l && list[i - 2].lessonId == l;
      expect(same, isFalse, reason: '3 of lesson $l in a row at $i');
    }
  }
  final sets = [
    for (var i = 0; i < list.length; i++)
      if (list[i].bucket == FeedBucket.set) i,
  ];
  expect(sets, isNotEmpty);
  expect(sets.first, lessThan(8));
  for (var i = 1; i < sets.length; i++) {
    expect(sets[i] - sets[i - 1], lessThanOrEqualTo(8), reason: '$sets');
  }
}

void main() {
  final now = DateTime(2026, 10, 21, 18);

  test('the first post changes with the seed and is a known card', () {
    final firsts = <String>{};
    for (var seed = 0; seed < 20; seed++) {
      final q = buildFeedQueue(
        pool: deck(),
        random: math.Random(seed),
        now: now,
      );
      expect(q.first.bucket, FeedBucket.known);
      firsts.add(q.first.key);
    }
    expect(firsts.length, greaterThanOrEqualTo(8));
  });

  test('the first post is never the one shown first last time', () {
    final pool = {
      FeedBucket.known: [
        const FeedItem(key: 'c:1', bucket: FeedBucket.known),
        const FeedItem(key: 'c:2', bucket: FeedBucket.known),
      ],
    };
    for (var seed = 0; seed < 10; seed++) {
      final q = buildFeedQueue(
        pool: pool,
        random: math.Random(seed),
        now: now,
        lastFirst: 'c:1',
      );
      expect(q.first.key, 'c:2');
    }
  });

  test('spread rules, sets every 8 posts and no repeats, over 2 batches', () {
    for (var seed = 0; seed < 20; seed++) {
      final pool = deck();
      final first = buildFeedQueue(
        pool: pool,
        random: math.Random(seed),
        now: now,
      );
      expect(first, hasLength(50));
      final more = buildFeedQueue(
        pool: pool,
        random: math.Random(seed + 99),
        now: now,
        before: first,
      );
      expectSpread([...first, ...more]);
    }
  });

  test('bucket shares stay within 8 points of the targets', () {
    for (var seed = 0; seed < 20; seed++) {
      final q = buildFeedQueue(
        pool: deck(),
        random: math.Random(seed),
        now: now,
      );
      for (final b in FeedBucket.values) {
        final share = q.where((i) => i.bucket == b).length / q.length;
        expect(
          (share - feedShares[b]!).abs(),
          lessThanOrEqualTo(0.08),
          reason: 'seed $seed $b $share',
        );
      }
    }
  });

  test('a new student gets only new cards, sets and quick questions', () {
    for (var seed = 0; seed < 10; seed++) {
      final q = buildFeedQueue(
        pool: deck(newStudent: true),
        random: math.Random(seed),
        now: now,
      );
      expect(q, isNotEmpty);
      expect(q.first.bucket, FeedBucket.fresh);
      expect(
        q.map((i) => i.bucket).toSet().difference({
          FeedBucket.fresh,
          FeedBucket.set,
          FeedBucket.quick,
        }),
        isEmpty,
      );
    }
  });

  test('new cards keep chapter order; the easiest comes first', () {
    final q = buildFeedQueue(
      pool: deck(newStudent: true),
      random: math.Random(1),
      now: now,
    );
    final fresh = q.where((i) => i.bucket == FeedBucket.fresh).toList();
    expect(fresh.first.order, 0);
  });

  test('cards shown 4 times today come back less often', () {
    final pool = {
      FeedBucket.known: [
        for (var i = 0; i < 2; i++)
          FeedItem(key: 'c:$i', bucket: FeedBucket.known, concept: 'x$i'),
      ],
    };
    var tired = 0;
    for (var seed = 0; seed < 200; seed++) {
      final q = buildFeedQueue(
        pool: pool,
        random: math.Random(seed),
        now: now,
        seen: {'c:0': SeenInfo(last: now, times: 9, today: 4)},
      );
      if (q.first.key == 'c:0') tired++;
    }
    expect(tired, lessThan(40));
  });

  test('an empty deck gives an empty feed, not a crash', () {
    expect(
      buildFeedQueue(pool: const {}, random: math.Random(1), now: now),
      isEmpty,
    );
  });
}
