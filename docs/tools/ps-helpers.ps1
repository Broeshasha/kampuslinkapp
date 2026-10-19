# =============================================================================
# KampusLink PowerShell helpers
# Load at the start of every session, from the repo folder:
#     . .\docs\tools\ps-helpers.ps1
# Works in Windows PowerShell 5.1 and PowerShell 7.
# =============================================================================
$ErrorActionPreference = 'Stop'

function Resolve-KampusPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

# Create or overwrite a file as UTF-8 WITHOUT BOM (use -Append to add a part to a long file).
function Write-Kampus {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content,
    [switch]$Append
  )
  $full = Resolve-KampusPath $Path
  $dir  = [System.IO.Path]::GetDirectoryName($full)
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $text = $Content -replace "`r`n", "`n"
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  if ($Append) { [System.IO.File]::AppendAllText($full, $text, $utf8) }
  else         { [System.IO.File]::WriteAllText($full, $text, $utf8) }
  Write-Host ("wrote " + $Path + " (" + $text.Length + " chars)") -ForegroundColor Green
}

# Replace text that occurs EXACTLY ONCE in an existing file (keeps the file's line endings).
function Replace-InFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Old,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$New
  )
  $full = Resolve-KampusPath $Path
  if (-not (Test-Path -LiteralPath $full)) { throw "File not found: $Path" }
  $utf8  = New-Object System.Text.UTF8Encoding($false)
  $raw   = [System.IO.File]::ReadAllText($full)
  $crlf  = $raw.Contains("`r`n")
  $text  = $raw -replace "`r`n", "`n"
  $oldN  = $Old -replace "`r`n", "`n"
  $newN  = $New -replace "`r`n", "`n"
  $count = ([regex]::Matches($text, [regex]::Escape($oldN))).Count
  if ($count -ne 1) { throw "Replace-InFile: expected exactly 1 match in $Path but found $count. Nothing was changed." }
  $result = $text.Replace($oldN, $newN)
  if ($crlf) { $result = $result -replace "`n", "`r`n" }
  [System.IO.File]::WriteAllText($full, $result, $utf8)
  Write-Host ("patched " + $Path) -ForegroundColor Green
}

# pub get + format + analyze + tests, then a one-line summary to paste back.
function Step-Check {
  param([switch]$SkipTests)
  $global:KampusCheckOk = $false
  Write-Host '== flutter pub get ==' -ForegroundColor Cyan
  flutter pub get | Select-Object -Last 2 | Out-Host
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

  Write-Host '== dart format ==' -ForegroundColor Cyan
  $dirs = @('lib')
  if (Test-Path -LiteralPath 'test') { $dirs += 'test' }
  dart format $dirs | Out-Host

  Write-Host '== flutter analyze ==' -ForegroundColor Cyan
  flutter analyze --no-pub | Out-Host
  $analyzeExit = $LASTEXITCODE

  $testExit = 0
  $testNote = 'skipped'
  if (-not $SkipTests) {
    if (Test-Path -LiteralPath 'test') {
      Write-Host '== flutter test ==' -ForegroundColor Cyan
      flutter test --no-pub | Out-Host
      $testExit = $LASTEXITCODE
      $testNote = if ($testExit -eq 0) { 'pass' } else { 'FAIL' }
    } else { $testNote = 'no test folder yet' }
  }

  $global:KampusCheckOk = ($analyzeExit -eq 0 -and $testExit -eq 0)
  $analyzeNote = if ($analyzeExit -eq 0) { 'clean' } else { 'ISSUES' }
  $color = if ($analyzeExit -eq 0 -and $testExit -eq 0) { 'Green' } else { 'Red' }
  Write-Host ("STEP-CHECK SUMMARY: analyze=" + $analyzeNote + " | tests=" + $testNote) -ForegroundColor $color
  if ($analyzeExit -ne 0 -or $testExit -ne 0) { Write-Host 'Do not commit. Paste the output above to the AI.' -ForegroundColor Yellow }
}

# Commit everything with a message like "feat(render): paragraph block".
function Step-Commit {
  param([Parameter(Mandatory = $true)][string]$Message)
  git add -A | Out-Host
  git commit -m $Message | Out-Host
  git log --oneline -1 | Out-Host
  git status --short | Out-Host
}

# Show where we are (paste this when something looks wrong).
function Show-Where {
  Write-Host ('folder : ' + (Get-Location).Path)
  Write-Host ('branch : ' + (git branch --show-current))
  git status --short | Out-Host
  git log --oneline -5 | Out-Host
}
Write-Host 'KampusLink helpers loaded: Write-Kampus, Replace-InFile, Step-Check, Step-Commit, Show-Where' -ForegroundColor Cyan

# Push the current branch and PROVE GitHub has the same commit (no red noise).
function Step-Push {
  $ErrorActionPreference = 'Continue'
  git push --quiet 2>&1 | Out-Null
  $local = (git rev-parse HEAD).Trim()
  $remote = (git rev-parse '@{u}' 2>$null)
  if ($local -eq $remote) { Write-Host ('PUSHED OK: ' + $local.Substring(0, 7)) -ForegroundColor Green }
  else { Write-Host ('PUSH NOT CONFIRMED: local ' + $local.Substring(0, 7) + ' / github ' + $remote) -ForegroundColor Red }
}
