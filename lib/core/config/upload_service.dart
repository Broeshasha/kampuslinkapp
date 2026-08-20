import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadService {
  static const _workerUrl = 'https://kampuslink-upload-worker.chidafarai06.workers.dev';

  static Future<String?> upload(Uint8List bytes, String folder, String filename) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('UploadService: no session, cannot upload');
      return null;
    }

    final request = http.MultipartRequest('POST', Uri.parse(_workerUrl))
      ..fields['folder'] = folder
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      debugPrint('UploadService failed: ${response.statusCode} — $body');
      return null;
    }

    final url = RegExp(r'"url":"([^"]+)"').firstMatch(body)?.group(1);
    if (url == null) {
      debugPrint('UploadService: no url found in response body: $body');
    }
    return url;
  }
}