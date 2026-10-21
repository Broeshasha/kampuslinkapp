import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_failure.dart';

enum DownloadErrorKind { offline, timeout, server, storage, database, unknown }

/// Why a module download stopped, with the details the lead asked for
/// (step, code, attempts, time) so a failure in the field can be named.
class DownloadFailure {
  const DownloadFailure({
    required this.moduleId,
    required this.step,
    required this.kind,
    required this.code,
    required this.message,
    this.attempts = 1,
    this.seconds,
  });

  factory DownloadFailure.from(
    Object error, {
    required int moduleId,
    required String step,
    int attempts = 1,
    int? seconds,
  }) {
    final text = '$error';
    return DownloadFailure(
      moduleId: moduleId,
      step: step,
      kind: classify(error),
      code: error is PostgrestException ? (error.code ?? '') : '',
      message: text.length > 240 ? text.substring(0, 240) : text,
      attempts: attempts,
      seconds: seconds,
    );
  }

  final int moduleId;
  final String step;
  final DownloadErrorKind kind;
  final String code;
  final String message;
  final int attempts;
  final int? seconds;

  /// The text behind "Details" (Copy button) and in Crashlytics.
  String get details =>
      'module=$moduleId step=$step kind=${kind.name}'
      '${code.isEmpty ? '' : ' code=$code'} attempts=$attempts'
      '${seconds == null ? '' : ' after ${seconds}s'} error=$message';

  /// Retrying makes sense only for network-ish problems.
  bool get transient =>
      kind == DownloadErrorKind.offline ||
      kind == DownloadErrorKind.timeout ||
      kind == DownloadErrorKind.server;

  static DownloadErrorKind classify(Object error) {
    if (error is TimeoutException) return DownloadErrorKind.timeout;
    if (error is OfflineFailure) return DownloadErrorKind.offline;
    if (error is PostgrestException) {
      return error.code == '57014'
          ? DownloadErrorKind.timeout
          : DownloadErrorKind.server;
    }
    final s = '$error'.toLowerCase();
    if (s.contains('quota') ||
        s.contains('sqlite_full') ||
        s.contains('disk is full') ||
        s.contains('no space')) {
      return DownloadErrorKind.storage;
    }
    if (s.contains('sqlite') ||
        s.contains('drift') ||
        s.contains('indexeddb') ||
        s.contains('opfs')) {
      return DownloadErrorKind.database;
    }
    if (s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('failed host lookup') ||
        s.contains('xmlhttprequest') ||
        s.contains('failed to fetch') ||
        s.contains('network')) {
      return DownloadErrorKind.offline;
    }
    return DownloadErrorKind.unknown;
  }
}
