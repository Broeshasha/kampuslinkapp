import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/features/modules/module_sections.dart';
import 'package:kampuslink/features/preview/preview_page.dart';

ModuleRow module(int id, int? semester) => ModuleRow(
  id: id,
  name: 'M$id',
  semester: semester,
  serverVersion: 1,
  localVersion: 1,
  lessonCount: 0,
  lessonsDone: 0,
  resourceCount: 0,
  languages: 'fr',
);

void main() {
  final list = [
    module(1, 1),
    module(2, 2),
    module(3, 3),
    module(4, 3),
    module(5, 4),
  ];

  test('current semester first, pinned next, the rest under previous', () {
    final s = moduleSections(list, current: 3, pinned: [1]);
    expect(s.map((e) => e.kind), [
      SectionKind.current,
      SectionKind.pinned,
      SectionKind.previous,
    ]);
    expect(s[0].modules.map((m) => m.id), [3, 4]);
    expect(s[1].semester, 1);
    expect(s[1].modules.map((m) => m.id), [1]);
    expect(s[2].modules.map((m) => m.id), [2, 5]);
  });

  test('a pinned semester without modules is not shown', () {
    final s = moduleSections(list, current: 3, pinned: [6]);
    expect(s.map((e) => e.kind), [SectionKind.current, SectionKind.previous]);
  });

  test('no current semester: one section per semester, as before', () {
    final s = moduleSections(list);
    expect(s.map((e) => e.semester), [1, 2, 3, 4]);
    expect(s.every((e) => e.kind == SectionKind.semester), isTrue);
  });

  test('draft preview: ids missing from the student copy are drafts', () {
    expect(draftIds([1, 2, 3], [1, 3]), {'2'});
    expect(draftIds(['s1', 's2'], const []), {'s1', 's2'});
  });
}
