/// Content review (bac maths): the correct answer is first in 93 % of the
/// questions. The phone shows the options in a shuffled order that is
/// STABLE per question and per student (same order every time), and every
/// answer is still recorded with the ORIGINAL index (server, outbox, saved
/// quiz state never see the display order).
///
/// Returns display slot -> original index. True/false and one-option
/// questions keep their order.
List<int> optionOrder(int questionId, String seed, int count) {
  final order = List<int>.generate(count, (i) => i);
  if (count < 3) return order;
  // Park-Miller: every product stays below 2^53 (same result on web).
  var x = 7;
  for (final c in '$seed:$questionId'.codeUnits) {
    x = (x * 31 + c) % 2147483647;
  }
  if (x == 0) x = 1;
  for (var i = count - 1; i > 0; i--) {
    x = (x * 48271) % 2147483647;
    final j = x % (i + 1);
    final t = order[i];
    order[i] = order[j];
    order[j] = t;
  }
  return order;
}
