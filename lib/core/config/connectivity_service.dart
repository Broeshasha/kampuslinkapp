import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide online/offline state, backed by connectivity_plus.
/// Screens listen via [isOnline] (a ValueNotifier) instead of each one
/// rolling its own connectivity check.
///
/// Works on Android, iOS, and web. On web this only reflects whether the
/// browser currently has a network connection while the tab is open --
/// there's no background awareness once the tab is closed, same limit
/// as the rest of the offline layer on web.
class ConnectivityService {
  ConnectivityService._();

  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  static StreamSubscription<List<ConnectivityResult>>? _sub;

  static Future<void> init() async {
    try {
      final initial = await Connectivity().checkConnectivity();
      isOnline.value = !initial.contains(ConnectivityResult.none);
    } catch (_) {
      isOnline.value = true;
    }

    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = !results.contains(ConnectivityResult.none);
    });
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
