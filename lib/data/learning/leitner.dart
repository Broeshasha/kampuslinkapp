/// Leitner boxes 1..5, same numbers as the server's review_card():
/// right = box + 1 (max 5), wrong = box 1; wait 10 min / 1 d / 3 d / 7 d / 14 d.
const leitnerDelays = [
  Duration(minutes: 10),
  Duration(days: 1),
  Duration(days: 3),
  Duration(days: 7),
  Duration(days: 14),
];

({int box, DateTime dueAt}) leitnerNext({
  required int box,
  required bool correct,
  required DateTime now,
}) {
  final next = correct ? (box + 1).clamp(1, 5) : 1;
  return (box: next, dueAt: now.add(leitnerDelays[next - 1]));
}
