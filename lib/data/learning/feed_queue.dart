import 'dart:math' as math;

/// The five kinds of posts in the Home feed (lead brief 2, section C).
enum FeedBucket {
  /// K: cards the student knows (Leitner box 3+): confidence.
  known,

  /// D: cards due now with box 1-2: spaced review.
  due,

  /// N: never-reviewed cards, in chapter order (soft unlock).
  fresh,

  /// S: carousel sets.
  set,

  /// Q: one quick MCQ from something the student knows.
  quick,
}

/// Target share of each bucket in a batch.
const feedShares = <FeedBucket, double>{
  FeedBucket.known: 0.50,
  FeedBucket.due: 0.20,
  FeedBucket.fresh: 0.12,
  FeedBucket.set: 0.12,
  FeedBucket.quick: 0.06,
};

/// One candidate post. [key] is unique across kinds ('c:12', 's:abc',
/// 'q:5'); [payload] is what the screen shows.
class FeedItem {
  const FeedItem({
    required this.key,
    required this.bucket,
    this.concept,
    this.lessonId,
    this.cardKind,
    this.difficulty = 2,
    this.order = 0,
    this.started = false,
    this.payload,
  });

  final String key;
  final FeedBucket bucket;
  final String? concept;
  final int? lessonId;
  final String? cardKind;
  final int difficulty;

  /// N: chapter order; S: position. Lower comes first.
  final int order;

  /// S: a set the student already opened and did not finish.
  final bool started;
  final Object? payload;

  @override
  String toString() => key;
}

/// What the phone remembers about a post (feed_seen).
class SeenInfo {
  const SeenInfo({
    required this.last,
    this.times = 1,
    this.today = 1,
    this.outcome,
  });

  final DateTime last;
  final int times;

  /// Times shown on the day of [last].
  final int today;
  final String? outcome;
}

/// Builds one batch of the feed. Pure: same inputs + same seed = same
/// queue, so it is testable.
///
/// * WARM-UP: the first post of a session is a known card (else the
///   easiest new card), never [lastFirst], never a due card.
/// * a set every 6-8 posts when sets exist (max 1 new set per 6 posts);
/// * the other slots follow the bucket shares with light jitter;
/// * inside a bucket: weighted random (older = likelier, shown 3+ times
///   today = rarer); N and S go in their own order;
/// * SPREAD: never the same concept twice in a row, never 3 posts of the
///   same lesson in a row (a set is a different format, it may follow),
///   never 3 cards of the same kind in a row;
/// * never twice in one session ([before] = what is already queued), and
///   once everything was shown, only posts not in the last 40.
List<FeedItem> buildFeedQueue({
  required Map<FeedBucket, List<FeedItem>> pool,
  required math.Random random,
  required DateTime now,
  Map<String, SeenInfo> seen = const {},
  String? lastFirst,
  List<FeedItem> before = const [],
  int size = 50,
}) {
  final used = {for (final i in before) i.key};
  final seq = <FeedItem>[...before];
  final out = <FeedItem>[];

  Set<String> recent() => {
    for (final i in seq.skip(math.max(0, seq.length - 40))) i.key,
  };

  List<FeedItem> available(FeedBucket b) {
    final all = pool[b] ?? const <FeedItem>[];
    final fresh = [
      for (final i in all)
        if (!used.contains(i.key)) i,
    ];
    if (fresh.isNotEmpty) return fresh;
    final r = recent();
    return [
      for (final i in all)
        if (!r.contains(i.key)) i,
    ];
  }

  bool fits(FeedItem item) {
    if (seq.isEmpty) return true;
    final prev = seq.last;
    if (item.concept != null && item.concept == prev.concept) return false;
    if (seq.length >= 2) {
      final p2 = seq[seq.length - 2];
      if (item.bucket != FeedBucket.set &&
          item.lessonId != null &&
          prev.lessonId == item.lessonId &&
          p2.lessonId == item.lessonId) {
        return false;
      }
      if (item.cardKind != null &&
          prev.cardKind == item.cardKind &&
          p2.cardKind == item.cardKind) {
        return false;
      }
    }
    return true;
  }

  double weight(FeedItem item) {
    final s = seen[item.key];
    if (s == null) return 3.0;
    final hours = now.difference(s.last).inMinutes / 60.0;
    var w = 0.5 + hours.clamp(0.0, 72.0) / 24.0;
    final sameDay =
        s.last.year == now.year &&
        s.last.month == now.month &&
        s.last.day == now.day;
    if (sameDay && s.today > 3) w *= 0.2;
    return w;
  }

  FeedItem? weighted(List<FeedItem> items) {
    FeedItem? best;
    var bestKey = double.negativeInfinity;
    for (final i in items) {
      final u = random.nextDouble().clamp(1e-12, 1.0);
      final k = math.log(u) / weight(i);
      if (k > bestKey) {
        bestKey = k;
        best = i;
      }
    }
    return best;
  }

  List<FeedItem> ordered(FeedBucket b, List<FeedItem> items) {
    final list = [...items];
    if (b == FeedBucket.set) {
      int rank(FeedItem i) => i.started
          ? 0
          : seen.containsKey(i.key)
          ? 2
          : 1;
      list.sort((a, c) {
        final r = rank(a).compareTo(rank(c));
        if (r != 0) return r;
        if (rank(a) == 2) {
          return seen[a.key]!.last.compareTo(seen[c.key]!.last);
        }
        return a.order.compareTo(c.order);
      });
    } else {
      list.sort((a, c) => a.order.compareTo(c.order));
    }
    return list;
  }

  FeedItem? pick(FeedBucket b, {bool strict = true}) {
    final items = [
      for (final i in available(b))
        if (!strict || fits(i)) i,
    ];
    if (items.isEmpty) return null;
    if (b == FeedBucket.fresh || b == FeedBucket.set) {
      return ordered(b, items).first;
    }
    return weighted(items);
  }

  void take(FeedItem item) {
    used.add(item.key);
    seq.add(item);
    out.add(item);
  }

  bool has(FeedBucket b) => available(b).isNotEmpty;

  // Shares, with the share of empty buckets given to K and N first.
  final shares = <FeedBucket, double>{
    for (final b in FeedBucket.values) b: has(b) ? feedShares[b]! : 0,
  };
  final lost = 1 - shares.values.fold<double>(0, (a, b) => a + b);
  if (lost > 0) {
    final first = [
      for (final b in [FeedBucket.known, FeedBucket.fresh])
        if (shares[b]! > 0) b,
    ];
    final takers = first.isNotEmpty
        ? first
        : [
            for (final b in FeedBucket.values)
              if (shares[b]! > 0) b,
          ];
    final base = takers.fold<double>(0, (a, b) => a + feedShares[b]!);
    for (final b in takers) {
      shares[b] = shares[b]! + lost * feedShares[b]! / base;
    }
  }
  if (shares.values.every((s) => s == 0)) return out;

  // 1. Warm-up (first post of the session only).
  if (before.isEmpty) {
    final known = [
      for (final i in available(FeedBucket.known))
        if (i.key != lastFirst) i,
    ];
    var first = weighted(known);
    if (first == null) {
      final fresh = ordered(FeedBucket.fresh, available(FeedBucket.fresh));
      final other = [
        for (final i in fresh)
          if (i.key != lastFirst) i,
      ];
      first = other.isNotEmpty
          ? other.first
          : (fresh.isNotEmpty ? fresh.first : null);
    }
    if (first != null) take(first);
  }

  // 2. Where the sets go: a gap of 6 to 8 posts.
  final setSlots = <int>{};
  final sets = available(FeedBucket.set).length;
  if (sets > 0) {
    // Position of the last set already queued, relative to this batch.
    int? lastSet;
    for (var i = seq.length - 1; i >= 0 && i >= seq.length - 8; i--) {
      if (seq[i].bucket == FeedBucket.set) {
        lastSet = i - seq.length;
        break;
      }
    }
    var at = lastSet == null
        ? (before.isEmpty ? 2 : 1) + random.nextInt(2)
        : math.max(0, lastSet + 6 + random.nextInt(3));
    while (at < size && setSlots.length < sets) {
      setSlots.add(at);
      at += 6 + random.nextInt(3);
    }
  }

  // 3. The other slots: smooth weighted round robin with jitter.
  final others = [
    for (final b in FeedBucket.values)
      if (b != FeedBucket.set && shares[b]! > 0) b,
  ];
  final otherTotal = others.fold<double>(0, (a, b) => a + shares[b]!);
  final credit = {for (final b in others) b: 0.0};

  for (var slot = out.length; slot < size; slot++) {
    FeedItem? item;
    if (setSlots.contains(slot)) {
      item = pick(FeedBucket.set);
    }
    if (item == null && others.isNotEmpty) {
      for (final b in others) {
        credit[b] = credit[b]! + shares[b]! / otherTotal;
      }
      final order = [...others]
        ..sort(
          (a, b) => (credit[b]! + random.nextDouble() * 0.15).compareTo(
            credit[a]! + random.nextDouble() * 0.15,
          ),
        );
      final wanted = order.first;
      item = pick(wanted);
      if (item != null) {
        credit[wanted] = credit[wanted]! - 1;
      } else {
        for (final b in [
          FeedBucket.known,
          FeedBucket.fresh,
          FeedBucket.due,
          FeedBucket.quick,
        ]) {
          if (b == wanted || !others.contains(b)) continue;
          item = pick(b);
          if (item != null) {
            credit[b] = credit[b]! - 1;
            break;
          }
        }
      }
    }
    if (item == null) {
      // Nothing fits the spread rules: relax them rather than stop.
      for (final b in [...others, FeedBucket.set]) {
        item = pick(b, strict: false);
        if (item != null) break;
      }
    }
    if (item == null) break;
    take(item);
  }
  return out;
}
