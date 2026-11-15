import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/learning/bac_source.dart';
import 'package:kampuslink/data/learning/option_order.dart';
import 'package:kampuslink/data/lessons/lesson_content.dart';
import 'package:kampuslink/data/sync/sync_controller.dart';
import 'package:kampuslink/features/cases/case_models.dart';
import 'package:kampuslink/render/figure_block.dart';

String _img(String type, int chars) =>
    '<image href="data:image/$type;base64,${'A' * chars}" width="10" height="10"/>';

String _svg(String inner) =>
    '<svg viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg">$inner</svg>';

void main() {
  test('B17: only a real bac source gives a badge year', () {
    expect(bacYearOf({'type': 'bac', 'year': 2019, 'session': 'june'}), 2019);
    expect(bacYearOf({'kind': 'bac', 'year': '2023'}), 2023);
    expect(bacYearOf({'type': 'kampuslink_bac_style'}), isNull);
    expect(bacYearOf({'type': 'bac'}), isNull);
    expect(bacYearOf(null), isNull);
    // A reworded drill only has based_on: the slide never reads it.
    final slide = CaseSlide.fromMap({
      'id': 's1',
      'role': 'quiz',
      'prompt': 'p',
      'options': ['a', 'b', 'c'],
      'correct_index': 1,
      'based_on': {'type': 'bac', 'year': 2018},
    });
    expect(slide.bacYear, isNull);
    final real = CaseSlide.fromMap({
      'id': 's2',
      'role': 'quiz',
      'prompt': 'p',
      'options': ['a', 'b', 'c'],
      'correct_index': 1,
      'source': {'type': 'bac', 'year': 2017},
    });
    expect(real.bacYear, 2017);
  });

  test('3-option questions are shuffled too, stable per student', () {
    final a = optionOrder(0, 'user-1|set-9:s1', 3);
    expect(a.toSet(), {0, 1, 2});
    expect(optionOrder(0, 'user-1|set-9:s1', 3), a);
    final firsts = {
      for (var i = 0; i < 40; i++) optionOrder(i, 'user-1', 3).first,
    };
    expect(firsts.length, greaterThan(1), reason: 'A is not always first');
  });

  test('B14: bac downloads Arabic (+ English for an English UI)', () {
    expect(contentLanguagesFor(ui: 'fr', bac: true), ['ar']);
    expect(contentLanguagesFor(ui: 'ar', bac: true), ['ar']);
    expect(contentLanguagesFor(ui: 'en', bac: true), ['en', 'ar']);
    expect(contentLanguagesFor(ui: 'ar', bac: false), ['ar', 'fr']);
    expect(contentLanguagesFor(ui: 'fr', bac: false), ['fr']);
  });

  test('B14: no French -> Arabic before English', () {
    expect(pickLanguage(['en', 'ar'], 'fr'), 'ar');
    expect(pickLanguage(['en', 'ar'], 'en'), 'en');
    expect(pickLanguage(['fr', 'ar'], 'en'), 'fr');
  });

  test('B17: photos inside SVG within the caps', () {
    expect(isSafeSvg(_svg(_img('png', 1000))), isTrue);
    expect(isSafeSvg(_svg(_img('webp', 1000) + _img('jpeg', 1000))), isTrue);
    // 300 KB of photo is fine even though the whole string is > 200 KB.
    expect(
      isSafeSvg(_svg(_img('png', 150 * 1024) + _img('png', 150 * 1024))),
      isTrue,
    );
    expect(isSafeSvg(_svg(_img('svg+xml', 100))), isFalse);
    expect(isSafeSvg(_svg(_img('gif', 100))), isFalse);
    expect(
      isSafeSvg(_svg(_img('png', 210 * 1024))),
      isFalse,
      reason: 'one too big',
    );
    expect(
      isSafeSvg(_svg([for (var i = 0; i < 4; i++) _img('png', 100)].join())),
      isFalse,
      reason: 'more than 3',
    );
    expect(
      isSafeSvg(
        _svg(
          [for (var i = 0; i < 3; i++) _img('png', 200 * 1024)].join() +
              _img('png', 0),
        ),
      ),
      isFalse,
    );
    expect(isSafeSvg(_svg('<image href="https://x.example/a.png"/>')), isFalse);
  });
}
