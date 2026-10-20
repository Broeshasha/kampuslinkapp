import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/render/segments.dart';

void main() {
  test('highlights: longest first, no overlap, missing ones ignored', () {
    final s = segmentText('Na2O and Na react', [
      {'text': 'Na', 'kind': 'term'},
      {'text': 'Na2O', 'kind': 'formula'},
      {'text': 'xyz', 'kind': 'value'},
    ]);
    expect(s, const [
      TextSegment('Na2O', SegmentKind.formula),
      TextSegment(' and ', SegmentKind.plain),
      TextSegment('Na', SegmentKind.term),
      TextSegment(' react', SegmentKind.plain),
    ]);
  });

  test('inline math is cut out and never highlighted inside', () {
    final s = segmentText(r'We write \(n = m\) here, n is moles', [
      {'text': 'n', 'kind': 'term'},
    ]);
    expect(s, const [
      TextSegment('We write ', SegmentKind.plain),
      TextSegment('n = m', SegmentKind.math),
      TextSegment(' here, ', SegmentKind.plain),
      TextSegment('n', SegmentKind.term),
      TextSegment(' is moles', SegmentKind.plain),
    ]);
  });
}
