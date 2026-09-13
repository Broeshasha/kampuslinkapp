$path = "C:\kampuslink\lib\main.dart"
$content = Get-Content $path -Raw

$old = @'
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KampusLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
'@

$new = @'
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KampusLink',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
'@

if (-not $content.Contains($old)) { Write-Host "ABORT: MaterialApp anchor not found"; exit }
$content = $content.Replace($old, $new)

Set-Content -Path $path -Value $content -NoNewline
Write-Host "main.dart patched with navigatorKey."