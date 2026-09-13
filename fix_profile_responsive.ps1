$path = "C:\kampuslink\lib\features\profile\user_profile_screen.dart"
$content = Get-Content $path -Raw

# --- 1. Add the import ---
$old1 = "import '../messages/chat_screen.dart';"
$new1 = "import '../messages/chat_screen.dart';`nimport '../../core/widgets/responsive_page.dart';"

if (-not $content.Contains($old1)) { Write-Host "ABORT: import anchor not found"; exit }
$content = $content.Replace($old1, $new1)

# --- 2. Wrap the returned Scaffold in ResponsivePage ---
$old2 = @'
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
'@

$new2 = @'
  Widget build(BuildContext context) {
    return ResponsivePage(
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
'@

if (-not $content.Contains($old2)) { Write-Host "ABORT: build-method anchor not found"; exit }
$content = $content.Replace($old2, $new2)

# --- 3. Close the extra ResponsivePage wrapper right after the Scaffold's closing bracket ---
$old3 = @'
              : _buildContent(),
    );
  }
'@

$new3 = @'
              : _buildContent(),
      ),
    );
  }
'@

if (-not $content.Contains($old3)) { Write-Host "ABORT: closing-bracket anchor not found"; exit }
$content = $content.Replace($old3, $new3)

Set-Content -Path $path -Value $content -NoNewline
Write-Host "user_profile_screen.dart wrapped in ResponsivePage."