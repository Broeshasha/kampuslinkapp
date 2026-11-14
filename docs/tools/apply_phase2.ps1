# Phase 2 step 1: TikTok feed (fixed rail), card skins, celebrations, coin bubble, semester loop removed.
. .\docs\tools\ps-helpers.ps1

function Add-ArbKeys {
  param([string]$Path, [string]$Entries, [string]$Marker)
  $full = Resolve-KampusPath $Path
  $raw = [System.IO.File]::ReadAllText($full)
  if ($raw.Contains($Marker)) { Write-Host ("already has keys: " + $Path) -ForegroundColor Yellow; return }
  $crlf = $raw.Contains("`r`n")
  $t = ($raw -replace "`r`n", "`n").TrimEnd()
  $t = $t.Substring(0, $t.Length - 1).TrimEnd()
  $out = $t + ",`n" + ($Entries -replace "`r`n", "`n") + "`n}`n"
  if ($crlf) { $out = $out -replace "`n", "`r`n" }
  [System.IO.File]::WriteAllText($full, $out, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ("added keys to " + $Path) -ForegroundColor Green
}

# 1 the stories bar no longer hides (swiping stays simple)
if (Test-Path 'lib\features\stories\stories_reveal.dart') { Remove-Item 'lib\features\stories\stories_reveal.dart' -Force; Write-Host 'removed stories_reveal.dart' -ForegroundColor Green }

# 2 card skins need a text colour
$themeText = [System.IO.File]::ReadAllText((Resolve-KampusPath 'lib/core/theme/app_theme.dart'))
if (-not $themeText.Contains('withText(')) {
  Replace-InFile -Path 'lib/core/theme/app_theme.dart' -Old '  /// The same palette with another accent (an equipped Shop theme).' -New @'
  /// The same palette with another text colour (an equipped card skin).
  KampusColors withText(Color fg) => KampusColors(
    background: background,
    surface: surface,
    surfaceRaised: surfaceRaised,
    border: border,
    accent: accent,
    onAccent: onAccent,
    accentText: accentText,
    accentAlt: accentAlt,
    textPrimary: fg,
    textSecondary: fg.withValues(alpha: 0.75),
    official: official,
    community: community,
    danger: danger,
    success: success,
    warning: warning,
    xp: xp,
    streak: streak,
  );

  /// The same palette with another accent (an equipped Shop theme).
'@
}

# 3 the sync reads the semester saved on the phone (the semester provider listens to the sync: reading it was a loop)
$syncText = [System.IO.File]::ReadAllText((Resolve-KampusPath 'lib/data/sync/sync_controller.dart'))
if ($syncText.Contains('return _lastSemester = ref.read(currentSemesterProvider);')) {
  Replace-InFile -Path 'lib/data/sync/sync_controller.dart' -Old @'
    try {
      return _lastSemester = ref.read(currentSemesterProvider);
    } catch (error, stack) {
      appLog.warn('semester read failed, using saved value: $error\n$stack');
      return _lastSemester ?? _savedSemester();
    }
'@ -New @'
    return _lastSemester = _savedSemester() ?? _lastSemester;
'@
  Replace-InFile -Path 'lib/data/sync/sync_controller.dart' -Old @'
    final raw = ref.read(sharedPrefsProvider).getString('server_stats');
    if (raw == null) return null;
'@ -New @'
    final prefs = ref.read(sharedPrefsProvider);
    // A semester chosen offline (not on the server yet) wins.
    final pending = prefs.getString('study_level_pending');
    if (pending != null) {
      try {
        final p = jsonDecode(pending);
        if (p is Map && p.containsKey('semester')) {
          final s = p['semester'];
          return s is num ? s.toInt() : int.tryParse('${s ?? ''}');
        }
      } on FormatException {
        // fall back to the server copy below
      }
    }
    final raw = prefs.getString('server_stats');
    if (raw == null) return null;
'@
}

# 4 texts
Add-ArbKeys -Path 'lib/l10n/app_en.arb' -Marker '"feedShare"' -Entries @'
  "feedShare": "Share",
  "feedMore": "More"
'@
Add-ArbKeys -Path 'lib/l10n/app_fr.arb' -Marker '"feedShare"' -Entries @'
  "feedShare": "Partager",
  "feedMore": "Plus"
'@
Add-ArbKeys -Path 'lib/l10n/app_ar.arb' -Marker '"feedShare"' -Entries @'
  "feedShare": "\u0645\u0634\u0627\u0631\u0643\u0629",
  "feedMore": "\u0627\u0644\u0645\u0632\u064a\u062f"
'@

Add-Content -Path 'docs/logs/APP_LOG.txt' -Encoding UTF8 -Value @'

[2026-11-06] LANE: D5 | AI/Person: founder + Claude | WP: Phase 2 step 1 (feed)
DID: Home feed reels style: only the card moves, fixed side rail (module, like, save, share, more; mirrored in Arabic), double-tap like with big heart, pop/bounce buttons, card skins + celebrations from the shop, coin bubble when the server pays, answers flushed 3 s later; stories bar no longer hides; sync reads the semester saved on the phone (Riverpod loop removed).
'@
Write-Host 'PHASE 2 STEP 1 APPLIED. Next: Step-Check' -ForegroundColor Cyan
