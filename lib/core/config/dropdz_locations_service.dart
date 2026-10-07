import 'package:supabase_flutter/supabase_flutter.dart';

class Wilaya {
  final int id;
  final String name;
  const Wilaya({required this.id, required this.name});
}

class Commune {
  final String id; // DropDz commune ids are composite strings, e.g. "1-101"
  final String name;
  const Commune({required this.id, required this.name});
}

/// Reads wilayas from the app's existing `wilayas` table, and communes from
/// `dz_communes` (imported once from DropDz via a Worker -- calling DropDz
/// directly from the app would fail on web due to CORS, since their API
/// isn't built for browser requests). Cached in memory for the app session
/// since this data never changes.
class DropdzLocationsService {
  static List<Wilaya>? _wilayaCache;
  static final Map<int, List<Commune>> _communeCache = {};

  static Future<List<Wilaya>> getWilayas() async {
    if (_wilayaCache != null) return _wilayaCache!;

    final data = await Supabase.instance.client
        .from('wilayas')
        .select()
        .order('id')
        .timeout(const Duration(seconds: 10));

    final list = (data as List).map((w) => Wilaya(id: w['id'], name: w['name'])).toList();

    _wilayaCache = list;
    return list;
  }

  static Future<List<Commune>> getCommunes(int wilayaId) async {
    if (_communeCache.containsKey(wilayaId)) return _communeCache[wilayaId]!;

    final data = await Supabase.instance.client
        .from('dz_communes')
        .select()
        .eq('wilaya_id', wilayaId)
        .order('name')
        .timeout(const Duration(seconds: 10));

    final list =
        (data as List).map((c) => Commune(id: c['id'].toString(), name: c['name'])).toList();

    _communeCache[wilayaId] = list;
    return list;
  }
}