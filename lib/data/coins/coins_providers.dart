import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/connectivity/connectivity.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../providers.dart';
import '../remote/kampus_api.dart';
import '../sync/sync_results.dart';
import 'coins_models.dart';
import 'stories_models.dart';

const _shopKey = 'shop_items';

/// The wallet (coins, streak, freezes, inventory). The server decides every
/// coin; this only caches the last answer so the chip works offline.
class WalletController extends Notifier<Wallet?> {
  @override
  Wallet? build() {
    final uid = ref.watch(authControllerProvider.select((a) => a.userId));
    // A sync that paid coins: ask the server for the real balance.
    final sub = ref.read(syncResultsProvider).results.listen((r) {
      final coins = r['coins'];
      if (coins is num && coins > 0) unawaited(refresh());
    });
    ref.onDispose(sub.cancel);
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
    if (r case Ok(:final value)) {
      state = Wallet.fromMap(value);
      await ref
          .read(sharedPrefsProvider)
          .setString('wallet:$uid', jsonEncode(value));
    }
  }

  /// null = done, else an error code: insufficient_coins, freeze_limit,
  /// already_owned, item_not_found, item_inactive, offline, unknown.
  Future<String?> buy(String itemId) => _call((api) => api.buyItem(itemId));

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

/// Today's stories: the last copy from the phone at once (works offline),
/// refreshed with every sync. "Seen" and answers are also kept on the phone
/// so the rings and results stay right offline.
class StoriesController extends Notifier<StoriesData?> {
  Map<String, dynamic> _local = <String, dynamic>{};
  StoriesData? _server;
  String? _uid;

  @override
  StoriesData? build() {
    _uid = ref.watch(authControllerProvider.select((a) => a.userId));
    _local = <String, dynamic>{};
    _server = null;
    final uid = _uid;
    if (uid == null) return null;
    final prefs = ref.read(sharedPrefsProvider);
    final localRaw = prefs.getString('stories_local:$uid');
    if (localRaw != null) {
      try {
        _local = Map<String, dynamic>.of(asMap(jsonDecode(localRaw)));
      } on FormatException {
        _local = <String, dynamic>{};
      }
    }
    final raw = prefs.getString('stories:$uid');
    if (raw == null) return null;
    try {
      _server = StoriesData.fromMap(asMap(jsonDecode(raw)));
    } on FormatException {
      return null;
    }
    return _merged();
  }

  /// The server copy + what the student did on this phone; expired stories
  /// (24 h) are dropped even when offline.
  StoriesData? _merged() {
    final s = _server;
    if (s == null) return null;
    final now = DateTime.now();
    final list = <Story>[];
    for (final st in s.stories) {
      final exp = st.expiresAt;
      if (exp != null && now.isAfter(exp)) continue;
      final l = asMap(_local[st.key]);
      var story = st;
      if (l['seen'] == true && !st.seen) story = story.copyWith(seen: true);
      if (st.answeredChoice == null && l['choice'] is num) {
        story = story.copyWith(
          answeredChoice: asInt(l['choice']),
          answeredCorrect: l['correct'] == true,
        );
      }
      list.add(story);
    }
    return s.withStories(list);
  }

  Future<void> refresh() async {
    final api = ref.read(kampusApiProvider);
    final uid = _uid;
    if (api == null || uid == null || !ref.read(isOnlineProvider)) return;
    final r = await guard(api.getMyStories);
    if (r case Ok(:final value)) {
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setString('stories:$uid', jsonEncode(value));
      final fresh = StoriesData.fromMap(value);
      _server = fresh;
      final keys = {for (final s in fresh.stories) s.key};
      _local.removeWhere((k, _) => !keys.contains(k));
      await prefs.setString('stories_local:$uid', jsonEncode(_local));
      state = _merged();
    }
  }

  /// Updates the screen at once, saves to the phone in the background.
  Future<void> _setLocal(String key, Map<String, dynamic> patch) {
    _local[key] = <String, dynamic>{...asMap(_local[key]), ...patch};
    state = _merged();
    final uid = _uid;
    if (uid == null) return Future<void>.value();
    return ref
        .read(sharedPrefsProvider)
        .setString('stories_local:$uid', jsonEncode(_local));
  }

  Future<void> markSeen(String key) async {
    if (asMap(_local[key])['seen'] == true) return;
    final already = state?.stories.any((s) => s.key == key && s.seen) ?? false;
    unawaited(_setLocal(key, {'seen': true}));
    if (already) return;
    await ref.read(outboxRepositoryProvider).enqueue('story_view', {
      'story_key': key,
    });
  }

  /// The student answered. The right/wrong colours come from the story
  /// itself (instant, offline); the COINS come only from the server.
  Future<StoryOutcome> answer(Story story, int choice) async {
    final correct = choice == story.correctIndex;
    unawaited(_setLocal(story.key, {'choice': choice, 'correct': correct}));
    final opId = await ref.read(outboxRepositoryProvider).enqueue(
      'story_answer',
      {'story_key': story.key, 'choice': choice},
    );
    final sync = ref.read(outboxSyncProvider);
    if (sync == null || !ref.read(isOnlineProvider)) {
      return StoryOutcome(correct: correct);
    }
    final waiter = ref.read(syncResultsProvider).waitFor(opId);
    unawaited(sync.flush());
    final r = await waiter;
    if (r == null) return StoryOutcome(correct: correct);
    final coins = r['coins'];
    return StoryOutcome(
      correct: correct,
      coins: r['status'] == 'rejected' ? 0 : (coins is num ? coins.toInt() : 0),
    );
  }
}

final storiesControllerProvider =
    NotifierProvider<StoriesController, StoriesData?>(StoriesController.new);

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
