import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/learning/option_order.dart';

void main() {
  test('same student + question = same order every time', () {
    expect(optionOrder(42, 'user-a', 4), optionOrder(42, 'user-a', 4));
  });

  test('every option appears once', () {
    for (var q = 1; q < 50; q++) {
      final o = optionOrder(q, 'user-a', 4)..sort();
      expect(o, [0, 1, 2, 3]);
    }
  });

  test('the first option is not first most of the time any more', () {
    var first = 0;
    for (var q = 1; q <= 400; q++) {
      if (optionOrder(q, 'user-a', 4).first == 0) first++;
    }
    expect(first, inInclusiveRange(60, 140)); // about 1 in 4
  });

  test('true/false keeps its order', () {
    expect(optionOrder(7, 'user-a', 2), [0, 1]);
  });
}
