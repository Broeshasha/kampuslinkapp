import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/learning/leitner.dart';

void main() {
  final now = DateTime(2026, 1, 1, 9);

  test('a new card answered right goes to box 2, due in 1 day', () {
    expect(leitnerNext(box: 1, correct: true, now: now), (
      box: 2,
      dueAt: now.add(const Duration(days: 1)),
    ));
  });

  test('boxes stop at 5 (14 days)', () {
    expect(leitnerNext(box: 4, correct: true, now: now), (
      box: 5,
      dueAt: now.add(const Duration(days: 14)),
    ));
    expect(leitnerNext(box: 5, correct: true, now: now), (
      box: 5,
      dueAt: now.add(const Duration(days: 14)),
    ));
  });

  test('a wrong answer sends the card back to box 1 (10 minutes)', () {
    expect(leitnerNext(box: 4, correct: false, now: now), (
      box: 1,
      dueAt: now.add(const Duration(minutes: 10)),
    ));
  });
}
