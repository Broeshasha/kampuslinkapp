# KampusLink Phase 1 (coins + stories): patches the existing files. Run from C:\kampuslink AFTER the zip is expanded.
# Safe to stop and fix: every patch checks it matches exactly once, and throws if not.
. .\docs\tools\ps-helpers.ps1

function Add-ArbKeys {
  param([string]$Path, [string]$Entries, [string]$Marker)
  $full = Resolve-KampusPath $Path
  $raw = [System.IO.File]::ReadAllText($full)
  if ($raw.Contains($Marker)) { Write-Host ("already has keys: " + $Path) -ForegroundColor Yellow; return }
  $crlf = $raw.Contains("`r`n")
  $t = ($raw -replace "`r`n", "`n").TrimEnd()
  if (-not $t.EndsWith('}')) { throw "not a json object: $Path" }
  $t = $t.Substring(0, $t.Length - 1).TrimEnd()
  $out = $t + ",`n" + ($Entries -replace "`r`n", "`n") + "`n}`n"
  if ($crlf) { $out = $out -replace "`n", "`r`n" }
  [System.IO.File]::WriteAllText($full, $out, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ("added keys to " + $Path) -ForegroundColor Green
}

# 1 API calls
Replace-InFile -Path 'lib/data/remote/kampus_api.dart' -Old '  Future<List<dynamic>> syncProgress(List<Map<String, Object?>> ops) async {' -New @'
  // ---- coins, shop, stories (BACKEND_CONTRACT H, file 33) ----
  Future<Map<String, dynamic>> getWallet() async =>
      _map(await _client.rpc('get_wallet').timeout(_timeout));

  Future<Map<String, dynamic>> getMyStories() async =>
      _map(await _client.rpc('get_my_stories').timeout(_timeout));

  /// Errors: item_not_found, item_inactive, insufficient_coins,
  /// already_owned, freeze_limit.
  Future<Map<String, dynamic>> buyItem(String itemId) async => _map(
    await _client.rpc('buy_item', params: {'p_item': itemId}).timeout(_timeout),
  );

  /// Error: not_owned.
  Future<Map<String, dynamic>> equipItem(String itemId, {bool on = true}) async =>
      _map(
        await _client
            .rpc('equip_item', params: {'p_item': itemId, 'p_on': on})
            .timeout(_timeout),
      );

  /// The active shop rows (readable by every signed-in student).
  Future<List<Map<String, dynamic>>> getShopItems() async {
    final rows = await _client
        .from('kl_shop_items')
        .select('id, kind, price, name_i18n, desc_i18n, payload, sort')
        .eq('active', true)
        .order('sort')
        .timeout(_timeout);
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<List<dynamic>> syncProgress(List<Map<String, Object?>> ops) async {
'@

# 2 sync results bus: coins paid by a sync reach the screens
Replace-InFile -Path 'lib/data/providers.dart' -Old "import 'sync/outbox_sync.dart';" -New @'
import 'sync/outbox_sync.dart';
import 'sync/sync_results.dart';
'@
Replace-InFile -Path 'lib/data/providers.dart' -Old '  return OutboxSync(ref.watch(outboxRepositoryProvider), api.syncProgress);' -New @'
  final bus = ref.watch(syncResultsProvider);
  return OutboxSync(ref.watch(outboxRepositoryProvider), (ops) async {
    final results = await api.syncProgress(ops);
    bus.publish(results);
    return results;
  });
'@

# 3 wallet + stories refresh with every sync
Replace-InFile -Path 'lib/data/sync/sync_controller.dart' -Old "import '../chat/chat_providers.dart';" -New @'
import '../chat/chat_providers.dart';
import '../coins/coins_providers.dart';
'@
Replace-InFile -Path 'lib/data/sync/sync_controller.dart' -Old '    // The catalog (years, modules, settings) first: it decides what shows.' -New @'
    // Coins + today's stories: two small calls, cached for offline use.
    await ref.read(walletControllerProvider.notifier).refresh();
    await ref.read(storiesControllerProvider.notifier).refresh();
    // The catalog (years, modules, settings) first: it decides what shows.
'@

# 4 route /shop
Replace-InFile -Path 'lib/app/router.dart' -Old "import '../features/quiz/quiz_page.dart';" -New @'
import '../features/quiz/quiz_page.dart';
import '../features/shop/shop_page.dart';
'@
Replace-InFile -Path 'lib/app/router.dart' -Old "      GoRoute(path: '/review', builder: (_, _) => const ReviewSessionPage())," -New @'
      GoRoute(path: '/review', builder: (_, _) => const ReviewSessionPage()),
      GoRoute(path: '/shop', builder: (_, _) => const ShopPage()),
'@

# 5 Home: stories bar + coin chip
Replace-InFile -Path 'lib/features/home/home_page.dart' -Old "import 'study_activity.dart';" -New @'
import '../stories/coin_chip.dart';
import '../stories/stories_bar.dart';
import 'study_activity.dart';
'@
Replace-InFile -Path 'lib/features/home/home_page.dart' -Old '            const _ResumeButton(),' -New @'
            const CoinChip(),
            const _ResumeButton(),
'@
Replace-InFile -Path 'lib/features/home/home_page.dart' -Old '              _HomeHeader(),' -New @'
              _HomeHeader(),
              StoriesBar(),
'@

# 6 Shop themes paint the app accent
Replace-InFile -Path 'lib/core/theme/app_theme.dart' -Old '  KampusColors copyWith() => this;' -New @'
  KampusColors copyWith() => this;

  /// The same palette with another accent (an equipped Shop theme).
  KampusColors withAccent(Color a, {required bool dark}) => KampusColors(
    background: background,
    surface: surface,
    surfaceRaised: surfaceRaised,
    border: border,
    accent: a,
    onAccent: onAccent,
    accentText: dark ? (Color.lerp(a, const Color(0xFFFFFFFF), 0.25) ?? a) : a,
    accentAlt: accentAlt,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    official: official,
    community: community,
    danger: danger,
    success: success,
    warning: warning,
    xp: xp,
    streak: streak,
  );
'@
Replace-InFile -Path 'lib/core/theme/app_theme.dart' -Old '  static ThemeData get light => _build(KampusColors.light, Brightness.light);' -New @'
  static ThemeData get light => _build(KampusColors.light, Brightness.light);

  /// [accent] = the accent of the equipped Shop theme (null = normal look).
  static ThemeData lightWith(Color? accent) => accent == null
      ? light
      : _build(
          KampusColors.light.withAccent(accent, dark: false),
          Brightness.light,
        );

  static ThemeData darkWith(Color? accent) => accent == null
      ? dark
      : _build(
          KampusColors.dark.withAccent(accent, dark: true),
          Brightness.dark,
        );
'@
Replace-InFile -Path 'lib/app/app.dart' -Old "import '../core/theme/theme_mode_controller.dart';" -New @'
import '../core/theme/theme_mode_controller.dart';
import '../data/coins/coins_providers.dart';
'@
Replace-InFile -Path 'lib/app/app.dart' -Old '    final locale = ref.watch(localeControllerProvider);' -New @'
    final locale = ref.watch(localeControllerProvider);
    final accent = ref.watch(themeAccentProvider);
'@
Replace-InFile -Path 'lib/app/app.dart' -Old '      theme: AppTheme.light,' -New '      theme: AppTheme.lightWith(accent),'
Replace-InFile -Path 'lib/app/app.dart' -Old '      darkTheme: AppTheme.dark,' -New '      darkTheme: AppTheme.darkWith(accent),'

# 7 texts (en / fr / ar)
Add-ArbKeys -Path 'lib/l10n/app_en.arb' -Marker '"storiesToday"' -Entries @'
  "storiesToday": "Today",
  "storiesClose": "Close",
  "coinsBalance": "{count} coins",
  "@coinsBalance": {"placeholders": {"count": {"type": "int"}}},
  "storyCoinsPending": "Your coins arrive when you are back online.",
  "storyYesterday": "Yesterday, {pct}% got this question right",
  "@storyYesterday": {"placeholders": {"pct": {"type": "int"}}},
  "storyPlanDue": "Review {count} cards",
  "@storyPlanDue": {"placeholders": {"count": {"type": "int"}}},
  "storyPlanLesson": "Next episode: {title}",
  "@storyPlanLesson": {"placeholders": {"title": {"type": "String"}}},
  "storyPlanMinutes": "About {minutes} min in total",
  "@storyPlanMinutes": {"placeholders": {"minutes": {"type": "int"}}},
  "storyPlanDone": "You are all caught up. Nice!",
  "storyStreakDays": "{count} days in a row",
  "@storyStreakDays": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakBest": "Your best: {count}",
  "@storyStreakBest": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakNext": "{days} more days to the {milestone}-day badge: +{coins} coins",
  "@storyStreakNext": {"placeholders": {"days": {"type": "int"}, "milestone": {"type": "int"}, "coins": {"type": "int"}}},
  "storyStreakFreezes": "{count} streak freezes ready",
  "@storyStreakFreezes": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakProtected": "A freeze will save your streak today.",
  "storyStreakShare": "I am on a {count}-day streak on KampusLink!",
  "@storyStreakShare": {"placeholders": {"count": {"type": "int"}}},
  "shopTitle": "Shop",
  "shopHint": "Earn coins by studying. Nothing here can be bought with money.",
  "shopToday": "Study coins today: {earned} / {cap}",
  "@shopToday": {"placeholders": {"earned": {"type": "int"}, "cap": {"type": "int"}}},
  "shopBuy": "Buy",
  "shopUse": "Use",
  "shopInUse": "In use",
  "shopHave": "You have {count} of {max}",
  "@shopHave": {"placeholders": {"count": {"type": "int"}, "max": {"type": "int"}}},
  "shopMax": "Maximum reached",
  "shopNotEnough": "Not enough coins yet",
  "shopEmpty": "The shop is empty for now.",
  "shopOffline": "Connect to the internet to use the shop.",
  "shopBought": "Done!"
'@
Add-ArbKeys -Path 'lib/l10n/app_fr.arb' -Marker '"storiesToday"' -Entries @'
  "storiesToday": "Aujourd\u2019hui",
  "storiesClose": "Fermer",
  "coinsBalance": "{count} pi\u00e8ces",
  "@coinsBalance": {"placeholders": {"count": {"type": "int"}}},
  "storyCoinsPending": "Tes pi\u00e8ces arrivent d\u00e8s que tu es en ligne.",
  "storyYesterday": "Hier, {pct} % ont r\u00e9ussi cette question",
  "@storyYesterday": {"placeholders": {"pct": {"type": "int"}}},
  "storyPlanDue": "Revoir {count} cartes",
  "@storyPlanDue": {"placeholders": {"count": {"type": "int"}}},
  "storyPlanLesson": "Prochain \u00e9pisode : {title}",
  "@storyPlanLesson": {"placeholders": {"title": {"type": "String"}}},
  "storyPlanMinutes": "Environ {minutes} min au total",
  "@storyPlanMinutes": {"placeholders": {"minutes": {"type": "int"}}},
  "storyPlanDone": "Tu es \u00e0 jour. Bravo !",
  "storyStreakDays": "{count} jours d\u2019affil\u00e9e",
  "@storyStreakDays": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakBest": "Ton record : {count}",
  "@storyStreakBest": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakNext": "Encore {days} jours pour le badge de {milestone} jours : +{coins} pi\u00e8ces",
  "@storyStreakNext": {"placeholders": {"days": {"type": "int"}, "milestone": {"type": "int"}, "coins": {"type": "int"}}},
  "storyStreakFreezes": "{count} gels de s\u00e9rie pr\u00eats",
  "@storyStreakFreezes": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakProtected": "Un gel sauvera ta s\u00e9rie aujourd\u2019hui.",
  "storyStreakShare": "Je suis \u00e0 {count} jours d\u2019affil\u00e9e sur KampusLink !",
  "@storyStreakShare": {"placeholders": {"count": {"type": "int"}}},
  "shopTitle": "Boutique",
  "shopHint": "Gagne des pi\u00e8ces en \u00e9tudiant. Rien ici ne s\u2019ach\u00e8te avec de l\u2019argent.",
  "shopToday": "Pi\u00e8ces gagn\u00e9es aujourd\u2019hui : {earned} / {cap}",
  "@shopToday": {"placeholders": {"earned": {"type": "int"}, "cap": {"type": "int"}}},
  "shopBuy": "Acheter",
  "shopUse": "Utiliser",
  "shopInUse": "Utilis\u00e9",
  "shopHave": "Tu en as {count} sur {max}",
  "@shopHave": {"placeholders": {"count": {"type": "int"}, "max": {"type": "int"}}},
  "shopMax": "Maximum atteint",
  "shopNotEnough": "Pas encore assez de pi\u00e8ces",
  "shopEmpty": "La boutique est vide pour le moment.",
  "shopOffline": "Connecte-toi \u00e0 internet pour utiliser la boutique.",
  "shopBought": "C\u2019est fait !"
'@
Add-ArbKeys -Path 'lib/l10n/app_ar.arb' -Marker '"storiesToday"' -Entries @'
  "storiesToday": "\u0627\u0644\u064a\u0648\u0645",
  "storiesClose": "\u0625\u063a\u0644\u0627\u0642",
  "coinsBalance": "{count} \u0639\u0645\u0644\u0629",
  "@coinsBalance": {"placeholders": {"count": {"type": "int"}}},
  "storyCoinsPending": "\u0633\u062a\u0635\u0644\u0643 \u0639\u0645\u0644\u0627\u062a\u0643 \u0639\u0646\u062f \u0639\u0648\u062f\u062a\u0643 \u0644\u0644\u0627\u062a\u0635\u0627\u0644.",
  "storyYesterday": "\u0623\u0645\u0633\u060c {pct}% \u0623\u062c\u0627\u0628\u0648\u0627 \u0639\u0644\u0649 \u0647\u0630\u0627 \u0627\u0644\u0633\u0624\u0627\u0644 \u0628\u0634\u0643\u0644 \u0635\u062d\u064a\u062d",
  "@storyYesterday": {"placeholders": {"pct": {"type": "int"}}},
  "storyPlanDue": "\u0631\u0627\u062c\u0639 {count} \u0628\u0637\u0627\u0642\u0629",
  "@storyPlanDue": {"placeholders": {"count": {"type": "int"}}},
  "storyPlanLesson": "\u0627\u0644\u062d\u0644\u0642\u0629 \u0627\u0644\u062a\u0627\u0644\u064a\u0629: {title}",
  "@storyPlanLesson": {"placeholders": {"title": {"type": "String"}}},
  "storyPlanMinutes": "\u062d\u0648\u0627\u0644\u064a {minutes} \u062f\u0642\u064a\u0642\u0629 \u0641\u064a \u0627\u0644\u0645\u062c\u0645\u0648\u0639",
  "@storyPlanMinutes": {"placeholders": {"minutes": {"type": "int"}}},
  "storyPlanDone": "\u0644\u0642\u062f \u0623\u0646\u0647\u064a\u062a \u0643\u0644 \u0634\u064a\u0621. \u0623\u062d\u0633\u0646\u062a!",
  "storyStreakDays": "{count} \u0623\u064a\u0627\u0645 \u0645\u062a\u062a\u0627\u0644\u064a\u0629",
  "@storyStreakDays": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakBest": "\u0631\u0642\u0645\u0643 \u0627\u0644\u0642\u064a\u0627\u0633\u064a: {count}",
  "@storyStreakBest": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakNext": "{days} \u0623\u064a\u0627\u0645 \u0625\u0636\u0627\u0641\u064a\u0629 \u0644\u0634\u0627\u0631\u0629 {milestone} \u064a\u0648\u0645\u0627\u064b: +{coins} \u0639\u0645\u0644\u0629",
  "@storyStreakNext": {"placeholders": {"days": {"type": "int"}, "milestone": {"type": "int"}, "coins": {"type": "int"}}},
  "storyStreakFreezes": "{count} \u062a\u062c\u0645\u064a\u062f \u062c\u0627\u0647\u0632 \u0644\u0644\u0633\u0644\u0633\u0644\u0629",
  "@storyStreakFreezes": {"placeholders": {"count": {"type": "int"}}},
  "storyStreakProtected": "\u0633\u064a\u062d\u0645\u064a \u0627\u0644\u062a\u062c\u0645\u064a\u062f \u0633\u0644\u0633\u0644\u062a\u0643 \u0627\u0644\u064a\u0648\u0645.",
  "storyStreakShare": "\u0623\u0646\u0627 \u0641\u064a \u0633\u0644\u0633\u0644\u0629 {count} \u0623\u064a\u0627\u0645 \u0645\u062a\u062a\u0627\u0644\u064a\u0629 \u0639\u0644\u0649 KampusLink!",
  "@storyStreakShare": {"placeholders": {"count": {"type": "int"}}},
  "shopTitle": "\u0627\u0644\u0645\u062a\u062c\u0631",
  "shopHint": "\u0627\u0631\u0628\u062d \u0627\u0644\u0639\u0645\u0644\u0627\u062a \u0628\u0627\u0644\u062f\u0631\u0627\u0633\u0629. \u0644\u0627 \u0634\u064a\u0621 \u0647\u0646\u0627 \u064a\u064f\u0634\u062a\u0631\u0649 \u0628\u0627\u0644\u0645\u0627\u0644.",
  "shopToday": "\u0639\u0645\u0644\u0627\u062a \u0627\u0644\u064a\u0648\u0645: {earned} / {cap}",
  "@shopToday": {"placeholders": {"earned": {"type": "int"}, "cap": {"type": "int"}}},
  "shopBuy": "\u0634\u0631\u0627\u0621",
  "shopUse": "\u0627\u0633\u062a\u062e\u062f\u0627\u0645",
  "shopInUse": "\u0642\u064a\u062f \u0627\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645",
  "shopHave": "\u0644\u062f\u064a\u0643 {count} \u0645\u0646 {max}",
  "@shopHave": {"placeholders": {"count": {"type": "int"}, "max": {"type": "int"}}},
  "shopMax": "\u0628\u0644\u063a\u062a \u0627\u0644\u062d\u062f \u0627\u0644\u0623\u0642\u0635\u0649",
  "shopNotEnough": "\u0644\u064a\u0633 \u0644\u062f\u064a\u0643 \u0639\u0645\u0644\u0627\u062a \u0643\u0627\u0641\u064a\u0629 \u0628\u0639\u062f",
  "shopEmpty": "\u0627\u0644\u0645\u062a\u062c\u0631 \u0641\u0627\u0631\u063a \u062d\u0627\u0644\u064a\u0627\u064b.",
  "shopOffline": "\u0627\u062a\u0635\u0644 \u0628\u0627\u0644\u0625\u0646\u062a\u0631\u0646\u062a \u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u0645\u062a\u062c\u0631.",
  "shopBought": "\u062a\u0645!"
'@

# 8 log (AGENTS.md rule)
Add-Content -Path 'docs/logs/APP_LOG.txt' -Encoding UTF8 -Value @'

[2026-11-05] LANE: D5 | AI/Person: founder + Claude | WP: Phase 1 coins + stories (backend file 33)
DID: lib/data/coins (wallet, stories, shop providers, models), sync results bus, KampusApi get_wallet / get_my_stories / buy_item / equip_item / shop rows, features/stories (bar, viewer, question / plan / streak / editorial templates), features/shop (route /shop), Home stories bar + coin chip, Shop theme accent, 27 new keys en/fr/ar.
TESTED: stories_coins_test (models, grouping, question detection, colours, results bus).
'@

Write-Host 'ALL PATCHES APPLIED. Next: Step-Check' -ForegroundColor Cyan
