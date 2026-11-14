import 'dart:convert';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/analytics.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../providers.dart';
import '../remote/kampus_api.dart';
import 'shop_models.dart';

const _shopKey = 'shop_items';

/// The wallet (spendable XP, streak, freezes, inventory). The server decides
/// everything; this only caches the last answer so the shop works offline.
class WalletController extends Notifier<Wallet?> {
  @override
  Wallet? build() {
    final uid = ref.watch(authControllerProvider.select((a) => a.userId));
    if (uid == null) return null;
    final raw = ref.read(sharedPrefsProvider).getString('wallet:$uid');
    if (raw == null) return null;
    try {
      return Wallet.fromMap(asMap(jsonDecode(raw)));
    } on FormatException {
      return null;
    }
  }

  Future<void> refresh() async {
    final api = ref.read(kampusApiProvider);
    final uid = ref.read(authControllerProvider).userId;
    if (api == null || uid == null || !ref.read(isOnlineProvider)) return;
    final r = await guard(api.getWallet);
    if (r case Ok(:final value)) await apply(value);
  }

  /// Stores a wallet the server sent (get_wallet or app_open).
  Future<void> apply(Map<String, dynamic> value) async {
    final uid = ref.read(authControllerProvider).userId;
    if (uid == null) return;
    state = Wallet.fromMap(value);
    await ref
        .read(sharedPrefsProvider)
        .setString('wallet:$uid', jsonEncode(value));
  }

  /// null = done, else an error code: insufficient_xp, freeze_limit,
  /// already_owned, not_for_sale, item_not_found, item_inactive, offline, unknown.
  Future<String?> buy(String itemId) async {
    final r = await _call((api) => api.buyItem(itemId));
    if (r == null) Analytics.log('shop_buy');
    return r;
  }

  Future<String?> equip(String itemId, {bool on = true}) =>
      _call((api) => api.equipItem(itemId, on: on));

  Future<String?> _call(
    Future<Map<String, dynamic>> Function(KampusApi api) run,
  ) async {
    final api = ref.read(kampusApiProvider);
    if (api == null || !ref.read(isOnlineProvider)) return 'offline';
    final r = await guard(() => run(api));
    switch (r) {
      case Ok():
        await refresh();
        return null;
      case Err(:final failure):
        return switch (failure) {
          ValidationFailure(:final code) => code,
          OfflineFailure() => 'offline',
          _ => 'unknown',
        };
    }
  }
}

final walletControllerProvider = NotifierProvider<WalletController, Wallet?>(
  WalletController.new,
);

List<ShopItem> readCachedShopItems(SharedPreferences prefs) {
  final raw = prefs.getString(_shopKey);
  if (raw == null) return const <ShopItem>[];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const <ShopItem>[];
    return [
      for (final m in list)
        if (m is Map) ShopItem.fromMap(m.cast<String, dynamic>()),
    ]..sort((a, b) => a.sort.compareTo(b.sort));
  } on FormatException {
    return const <ShopItem>[];
  }
}

/// The shop list: fresh when online, the last copy otherwise.
final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  final prefs = ref.read(sharedPrefsProvider);
  final api = ref.read(kampusApiProvider);
  if (api != null && ref.read(isOnlineProvider)) {
    final r = await guard(api.getShopItems);
    if (r case Ok(:final value)) {
      await prefs.setString(_shopKey, jsonEncode(value));
    }
  }
  return readCachedShopItems(prefs);
});

/// The accent colour of the equipped Shop theme (null = the normal look).
final themeAccentProvider = Provider<Color?>((ref) {
  final wallet = ref.watch(walletControllerProvider);
  final id = wallet?.equippedOfKind('theme');
  if (id == null) return null;
  final fresh = switch (ref.watch(shopItemsProvider)) {
    AsyncData(:final value) => value,
    _ => readCachedShopItems(ref.read(sharedPrefsProvider)),
  };
  for (final item in fresh) {
    if (item.id == id) return parseHexColor(item.payload['primary']);
  }
  return null;
});
