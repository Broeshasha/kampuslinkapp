import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadService {
  static const _workerUrl = 'https://kampuslink-upload-worker.YOUR-SUBDOMAIN.workers.dev';

  static Future<String?> upload(Uint8List bytes, String folder, String filename) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;

    final request = http.MultipartRequest('POST', Uri.parse(_workerUrl))
      ..fields['folder'] = folder
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final response = await request.send();
    if (response.statusCode != 200) return null;

    final body = await response.stream.bytesToString();
    final url = RegExp(r'"url":"([^"]+)"').firstMatch(body)?.group(1);
    return url;
  }
}