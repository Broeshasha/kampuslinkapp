$path = "C:\kampuslink\lib\features\community\community_screen.dart"
$content = Get-Content $path -Raw

# --- 1. Add the import ---
$old1 = "import '../../core/widgets/comments_sheet.dart';"
$new1 = "import '../../core/widgets/comments_sheet.dart';`nimport '../profile/user_profile_screen.dart';"

if (-not $content.Contains($old1)) { Write-Host "ABORT: import anchor not found"; exit }
$content = $content.Replace($old1, $new1)

# --- 2. Wrap avatar + username in one tappable region, avatar-zoom moves to long-press ---
$old2 = @'
          Row(
            children: [
              GestureDetector(
                onTap: post['avatar_url'] != null
                    ? () => showFullscreenImage(context, post['avatar_url'])
                    : null,
                child: ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: post['avatar_url'] != null
                      ? BlurHashImage(
                          imageUrl: post['avatar_url'],
                          blurhash: post['avatar_blurhash'],
                        )
                      : Container(
                          color: AppColors.background,
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              ),
              const SizedBox(width: 10),
              Text(
                '@${post['username'] ?? 'unknown'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
'@

$new2 = @'
          Row(
            children: [
              GestureDetector(
                onTap: post['user_id'] == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: post['user_id'],
                            ),
                          ),
                        ),
                onLongPress: post['avatar_url'] != null
                    ? () => showFullscreenImage(context, post['avatar_url'])
                    : null,
                child: Row(
                  children: [
                    ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: post['avatar_url'] != null
                      ? BlurHashImage(
                          imageUrl: post['avatar_url'],
                          blurhash: post['avatar_blurhash'],
                        )
                      : Container(
                          color: AppColors.background,
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '@${post['username'] ?? 'unknown'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
'@

if (-not $content.Contains($old2)) { Write-Host "ABORT: avatar-block anchor not found"; exit }
$content = $content.Replace($old2, $new2)

# --- 3. Close the two new wrapper widgets (inner Row, outer GestureDetector) right after the username Text's own closing ---
$old3 = @'
                ),
              ),
              const SizedBox(width: 8),
              if (post['pending'] == true) ...[
'@

$new3 = @'
                ),
              ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (post['pending'] == true) ...[
'@

if (-not $content.Contains($old3)) { Write-Host "ABORT: closing-brackets anchor not found"; exit }
$content = $content.Replace($old3, $new3)

Set-Content -Path $path -Value $content -NoNewline
Write-Host "community_screen.dart wired to UserProfileScreen."