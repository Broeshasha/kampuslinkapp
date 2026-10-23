import '../../data/db/app_database.dart';

enum SectionKind { current, pinned, previous, semester }

/// One header + its modules on the Modules tab.
class ModuleSection {
  const ModuleSection(this.kind, this.semester, this.modules);

  final SectionKind kind;
  final int? semester;
  final List<ModuleRow> modules;
}

/// Contract 11, B1: the current semester first, the pinned semesters next,
/// everything else under "Previous semesters". Without a current semester:
/// one section per semester, as before. Order inside a section is kept.
List<ModuleSection> moduleSections(
  List<ModuleRow> modules, {
  int? current,
  List<int> pinned = const [],
}) {
  if (current == null) {
    final out = <ModuleSection>[];
    for (final m in modules) {
      if (out.isEmpty || out.last.semester != m.semester) {
        out.add(ModuleSection(SectionKind.semester, m.semester, []));
      }
      out.last.modules.add(m);
    }
    return out;
  }
  final now = [
    for (final m in modules)
      if (m.semester == current) m,
  ];
  final pins = [
    for (final s in pinned)
      if (s != current)
        ModuleSection(SectionKind.pinned, s, [
          for (final m in modules)
            if (m.semester == s) m,
        ]),
  ].where((s) => s.modules.isNotEmpty);
  final shown = {current, ...pinned};
  final rest = [
    for (final m in modules)
      if (!shown.contains(m.semester)) m,
  ];
  return [
    if (now.isNotEmpty) ModuleSection(SectionKind.current, current, now),
    ...pins,
    if (rest.isNotEmpty) ModuleSection(SectionKind.previous, null, rest),
  ];
}
