$path = "C:\kampuslink\lib\features\community\community_screen.dart"
$raw = Get-Content $path -Raw
$content = $raw -replace "`r`n", "`n"

# --- 1. state variable ---
$old1 = "    bool submitting = false;`n    bool uploadingImage = false;"
$new1 = "    bool submitting = false;`n    bool uploadingImage = false;`n    bool isCampusNow = false;"

if (-not $content.Contains($old1)) { Write-Host "ABORT: state-var anchor not found"; exit }
$content = $content.Replace($old1, $new1)

# --- 2. toggle UI ---
$old2 = @'
                ),
              const SizedBox(height: 16),
              ElevatedButton(
'@ -replace "`r`n", "`n"

$new2 = @'
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: isCampusNow,
                    activeColor: AppColors.accent,
                    onChanged: (v) => setModalState(() => isCampusNow = v),
                  ),
                  const Expanded(
                    child: Text(
                      'Show in Campus Now (expires in 24h)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ElevatedButton(
'@ -replace "`r`n", "`n"

if (-not $content.Contains($old2)) { Write-Host "ABORT: toggle-placement anchor not found"; exit }
$content = $content.Replace($old2, $new2)

# --- 3. insert block: include the flag + conditional expiry override ---
$old3 = @'
                              await _supabase
                                  .from('community_posts')
                                  .insert({
                                'user_id': userId,
                                'content': content,
                                'image_url': imageUrl,
                                'image_blurhash': imageBlurhash,
                              }).timeout(const Duration(seconds: 8));
'@ -replace "`r`n", "`n"

$new3 = @'
                              await _supabase
                                  .from('community_posts')
                                  .insert({
                                'user_id': userId,
                                'content': content,
                                'image_url': imageUrl,
                                'image_blurhash': imageBlurhash,
                                'is_campus_now': isCampusNow,
                                if (isCampusNow)
                                  'expires_at': DateTime.now()
                                      .add(const Duration(hours: 24))
                                      .toIso8601String(),
                              }).timeout(const Duration(seconds: 8));
'@ -replace "`r`n", "`n"

if (-not $content.Contains($old3)) { Write-Host "ABORT: insert-block anchor not found"; exit }
$content = $content.Replace($old3, $new3)

$content = $content -replace "`n", "`r`n"
Set-Content -Path $path -Value $content -NoNewline
Write-Host "Campus Now toggle wired into composer."