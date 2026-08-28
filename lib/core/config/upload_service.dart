import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadService {
  static const _workerUrl = 'https://upload.kampus-link.com';

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
      debugPrint('UploadService failed: ${response.statusCode} â€” $body');
      return null;
    }

    final url = RegExp(r'"url":"([^"]+)"').firstMatch(body)?.group(1);
    if (url == null) {
      debugPrint('UploadService: no url found in response body: $body');
    }
    return url;
  }

  /// Deletes every file this user has ever uploaded (avatar, community
  /// posts, marketplace listings) from R2. Must be called BEFORE the
  /// account-deletion RPC -- it authenticates with the user's current
  /// Supabase session, which stops being valid the moment that RPC
  /// deletes the auth.users row.
  static Future<bool> deleteAllFiles() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;

    final response = await http.post(
      Uri.parse('$_workerUrl/delete-user-files'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.statusCode != 200) {
      debugPrint('UploadService.deleteAllFiles failed: ${response.statusCode} -- ${response.body}');
      return false;
    }
    return true;
  }
}
