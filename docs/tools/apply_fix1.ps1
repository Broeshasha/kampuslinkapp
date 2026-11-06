# Fix 1: stories bar hides while swiping the feed, crash-proof sync, duplicate contract section removed.
. .\docs\tools\ps-helpers.ps1

# 1 Home: the feed tells the stories bar when to hide / show
$home = [System.IO.File]::ReadAllText((Resolve-KampusPath 'lib/features/home/home_page.dart'))
if (-not $home.Contains('StoriesScrollWatcher')) {
  Replace-InFile -Path 'lib/features/home/home_page.dart' -Old "import '../stories/stories_bar.dart';" -New @'
import '../stories/stories_bar.dart';
import '../stories/stories_reveal.dart';
'@
  Replace-InFile -Path 'lib/features/home/home_page.dart' -Old '              Expanded(child: _Feed()),' -New '              Expanded(child: StoriesScrollWatcher(child: _Feed())),'
}

# 2 a crash inside the sync never leaves it stuck as "running" (downloads would stop)
$sync = [System.IO.File]::ReadAllText((Resolve-KampusPath 'lib/data/sync/sync_controller.dart'))
if (-not $sync.Contains('_syncNow(')) {
  Replace-InFile -Path 'lib/data/sync/sync_controller.dart' -Old '  Future<void> syncNow({bool force = false}) async {' -New @'
  Future<void> syncNow({bool force = false}) async {
    try {
      await _syncNow(force: force);
    } catch (error, stack) {
      // Never leave the sync stuck as "running": nothing would download again.
      appLog.error(error, stack, reason: 'syncNow crashed');
      state = state.copyWith(running: false, failure: UnknownFailure(error));
    }
  }

  Future<void> _syncNow({bool force = false}) async {
'@
}

# 3 the contract section I was added twice: keep only the first one
$full = Resolve-KampusPath 'docs/BACKEND_CONTRACT.txt'
$t = [System.IO.File]::ReadAllText($full)
$mark = 'I. ACHIEVEMENT POSTS + BIGGER SHOP'
$first = $t.IndexOf($mark)
$second = if ($first -ge 0) { $t.IndexOf($mark, $first + 1) } else { -1 }
if ($second -gt 0) {
  $cut = $t.LastIndexOf('-----', $second)
  $cut = $t.LastIndexOf("`n", $cut)
  $cut = $t.LastIndexOf("`n", $cut - 1)
  [System.IO.File]::WriteAllText($full, $t.Substring(0, $cut + 1), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host 'contract: duplicate section removed' -ForegroundColor Green
} else { Write-Host 'contract: no duplicate found' -ForegroundColor Yellow }

Write-Host 'FIX 1 APPLIED. Next: Step-Check' -ForegroundColor Cyan
