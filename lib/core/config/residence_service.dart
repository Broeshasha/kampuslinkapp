import 'package:supabase_flutter/supabase_flutter.dart';
import 'cached_fetch.dart';

/// A single ONOU-managed residence, scoped to a wilaya via its DOU.
class Residence {
  final int id;
  final String name;
  final int douId;
  final String douName;

  const Residence({
    required this.id,
    required this.name,
    required this.douId,
    required this.douName,
  });

  factory Residence.fromMap(Map<String, dynamic> m) => Residence(
        id: m['id'] as int,
        name: m['name'] as String,
        douId: m['dou_id'] as int,
        douName: m['dou_name'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'dou_id': douId,
        'dou_name': douName,
      };
}

/// Residences are ONOU housing data, not static like universities — they
/// can be added/renamed as the source system changes, so unlike
/// [algeriaUniversities] this stays a live Supabase table rather than a
/// hardcoded list. Same cache-first shape as the rest of the app though:
/// return the cache instantly, refresh in the background.
class ResidenceService {
  static final _supabase = Supabase.instance.client;

  /// Residences for a given wilaya, via their DOU. Cached per-wilaya so
  /// switching university during onboarding doesn't re-fetch everything.
  static Future<List<Residence>> forWilaya(int wilayaId) async {
    final cacheKey = 'residences_wilaya_$wilayaId';
    final cached = await CachedFetch.readCache(cacheKey);
    if (cached.isNotEmpty) {
      // Return cached instantly; refresh in the background for next time.
      _refresh(wilayaId, cacheKey);
      return cached.map(Residence.fromMap).toList();
    }
    return _refresh(wilayaId, cacheKey);
  }

  static Future<List<Residence>> _refresh(int wilayaId, String cacheKey) async {
    try {
      final rows = await _supabase
          .from('residences')
          .select('id, name, dou_id, dous!inner(name, wilaya_id)')
          .eq('dous.wilaya_id', wilayaId)
          .order('name')
          .timeout(const Duration(seconds: 8));

      final residences = (rows as List)
          .map((r) => Residence(
                id: r['id'] as int,
                name: r['name'] as String,
                douId: r['dou_id'] as int,
                douName: (r['dous'] as Map)['name'] as String,
              ))
          .toList();

      await CachedFetch.writeCache(cacheKey, residences.map((r) => r.toMap()).toList());
      return residences;
    } catch (_) {
      // Offline or slow — fall back to whatever's cached (possibly empty).
      final cached = await CachedFetch.readCache(cacheKey);
      return cached.map(Residence.fromMap).toList();
    }
  }
}
