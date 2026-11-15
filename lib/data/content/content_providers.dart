import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/l10n/locale_controller.dart';
import '../providers.dart';
import 'content_source.dart';

/// The "cdn" object of the last app_open ({module id: manifest path}).
const cdnPathsKey = 'cdn_paths';
const _breakerKey = 'cdn_breaker_until';

Future<Uint8List> _httpGet(http.Client client, Uri url) async {
  final r = await client.get(url);
  if (r.statusCode != 200) throw CdnError('HTTP ${r.statusCode}');
  return r.bodyBytes;
}

/// Cloudflare first, Supabase second (CDN-2). null without Supabase.
/// Web keeps Supabase only until the bucket allows the web origin (CORS).
final contentSourceProvider = Provider<ContentSource?>((ref) {
  final api = ref.watch(kampusApiProvider);
  if (api == null) return null;
  final prefs = ref.watch(sharedPrefsProvider);
  final modules = ref.watch(moduleRepositoryProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  return ContentSource(
    remoteManifest: api.getModuleManifest,
    remoteLesson: api.getLessonBundle,
    remoteExtras: api.getModuleExtras,
    remotePractice: api.getPractice,
    remotePaper: api.getExamPaper,
    remoteResources: api.getModuleResources,
    cdnGet: (url) => _httpGet(client, url),
    cdnPath: (id) => cdnPathFrom(prefs.getString(cdnPathsKey), id),
    serverVersion: modules.serverVersionOf,
    breaker: CdnBreaker(
      read: () => prefs.getString(_breakerKey),
      write: (value) {
        prefs.setString(_breakerKey, value);
      },
    ),
    enabled: !kIsWeb,
  );
});
