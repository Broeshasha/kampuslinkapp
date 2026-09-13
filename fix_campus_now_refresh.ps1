$path = "C:\kampuslink\lib\features\home\home_screen.dart"
$raw = Get-Content $path -Raw
$content = $raw -replace "`r`n", "`n"

# --- 1. let the strip accept a key ---
$old1 = "class _CampusNowStrip extends StatefulWidget {`n  const _CampusNowStrip();"
$new1 = "class _CampusNowStrip extends StatefulWidget {`n  const _CampusNowStrip({super.key});"

if (-not $content.Contains($old1)) { Write-Host "ABORT: strip-constructor anchor not found"; exit }
$content = $content.Replace($old1, $new1)

# --- 2. give _HomeScreenState a key to reach it, and pass it in ---
$old2 = "class _HomeScreenState extends State<HomeScreen> {`n  final _supabase = Supabase.instance.client;"
$new2 = "class _HomeScreenState extends State<HomeScreen> {`n  final _supabase = Supabase.instance.client;`n  final _campusNowKey = GlobalKey<_CampusNowStripState>();"

if (-not $content.Contains($old2)) { Write-Host "ABORT: state-field anchor not found"; exit }
$content = $content.Replace($old2, $new2)

$old3 = "                const _CampusNowStrip(),`n"
$new3 = "                _CampusNowStrip(key: _campusNowKey),`n"

if (-not $content.Contains($old3)) { Write-Host "ABORT: widget-instantiation anchor not found"; exit }
$content = $content.Replace($old3, $new3)

# --- 3. trigger its reload whenever Home's own _load() runs ---
$old4 = "  Future<void> _load() async {`n    final cached = await FeedCacheService.readCache();"
$new4 = "  Future<void> _load() async {`n    _campusNowKey.currentState?._load();`n    final cached = await FeedCacheService.readCache();"

if (-not $content.Contains($old4)) { Write-Host "ABORT: home-load anchor not found"; exit }
$content = $content.Replace($old4, $new4)

$content = $content -replace "`n", "`r`n"
Set-Content -Path $path -Value $content -NoNewline
Write-Host "Campus Now strip now refreshes with pull-to-refresh."