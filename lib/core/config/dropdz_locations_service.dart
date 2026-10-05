import 'dart:convert';
import 'package:http/http.dart' as http;

class Wilaya {
  final int id;
  final String code;
  final String name;
  const Wilaya({required this.id, required this.code, required this.name});
}

class Commune {
  final int id;
  final String name;
  const Commune({required this.id, required this.name});
}

/// Fetches wilaya/commune lists from DropDz's public location endpoints
/// (no API key required). Wilayas are cached in memory for the app session
/// since they never change; communes are cached per wilaya.
class DropdzLocationsService {
  static List<Wilaya>? _wilayaCache;
  static final Map<int, List<Commune>> _communeCache = {};

  static Future<List<Wilaya>> getWilayas() async {
    if (_wilayaCache != null) return _wilayaCache!;

    final resp = await http
        .get(Uri.parse('https://dropdz.space/api/v1/locations/wilayas'))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load wilayas (${resp.statusCode})');
    }

    final body = jsonDecode(resp.body);
    final list = (body['data'] as List)
        .map((w) => Wilaya(id: w['id'], code: w['code'].toString(), name: w['name']))
        .toList();

    _wilayaCache = list;
    return list;
  }

  static Future<List<Commune>> getCommunes(int wilayaId) async {
    if (_communeCache.containsKey(wilayaId)) return _communeCache[wilayaId]!;

    final resp = await http
        .get(Uri.parse('https://dropdz.space/api/v1/locations/wilayas/$wilayaId/communes'))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load communes (${resp.statusCode})');
    }

    final body = jsonDecode(resp.body);
    final list = (body['data'] as List)
        .map((c) => Commune(id: c['id'], name: c['name']))
        .toList();

    _communeCache[wilayaId] = list;
    return list;
  }
}