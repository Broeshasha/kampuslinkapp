/// B17: the year of a REAL bac item, from its "source" object
/// ({"type": "bac", "year": 2019, ...}; older drafts used "kind"). Anything
/// else - no source, a KampusLink bac-style item, or a reworded drill that
/// only has "based_on" - gives null: no 📜 badge.
int? bacYearOf(Object? source) {
  if (source is! Map) return null;
  final type = source['type'] ?? source['kind'];
  if (type != 'bac') return null;
  final y = source['year'];
  final year = y is num ? y.toInt() : int.tryParse('${y ?? ''}');
  return year != null && year >= 1990 && year <= 2100 ? year : null;
}
