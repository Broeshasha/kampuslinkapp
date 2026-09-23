$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Patch-File($path, $edits) {
    $raw = [System.IO.File]::ReadAllText($path)
    $content = $raw -replace "`r`n", "`n"
    foreach ($edit in $edits) {
        $old = $edit.Old -replace "`r`n", "`n"
        $new = $edit.New -replace "`r`n", "`n"
        if (-not $content.Contains($old)) {
            Write-Host "FAILED: anchor not found in $path" -ForegroundColor Red
            Write-Host "--- looking for ---"
            Write-Host $old
            throw "Patch aborted: anchor not found in $path"
        }
        $content = $content.Replace($old, $new)
    }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    Write-Host "$path patched OK" -ForegroundColor Green
}

# =========================================================
# 1) library_screen.dart
# =========================================================
$libPath = "C:\kampuslink\lib\features\library\library_screen.dart"

$lib_edit1_old = @'
  void openUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadResourceScreen()),
    ).then((added) {
      if (added == true) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
'@
$lib_edit1_new = @'
  void openUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadResourceScreen()),
    ).then((added) {
      if (added == true) _load(forceRefresh: true);
    });
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
'@

$lib_edit2_old = @'
      await _loadModules();
    } catch (e) {
'@
$lib_edit2_new = @'
      await _loadModules(forceRefresh: forceRefresh);
    } catch (e) {
'@

$lib_edit3_old = @'
  Future<void> _loadModules() async {
    if (_browsingAll) {
      final data = await _supabase
          .from('study_modules')
          .select('id, name, semester, ue_category, study_resources(count)')
          .order('semester')
          .order('name');
      if (!mounted) return;
      setState(() {
        _modules = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
      return;
    }

    // Prefer speciality-specific modules over domain-wide ones for this
    // year. Some specialities (e.g. Arabic Literature, Journalism &
    // Communication) have their own correct L1 content even though most
    // of their domain shares one L1 -- if speciality-scoped rows exist
    // for this year, domain-wide rows must NOT also be shown, or the
    // student sees both the right and the wrong curriculum stacked
    // together.
    final specialityRows = await _supabase
        .from('study_modules')
        .select('id, name, semester, ue_category, study_resources(count)')
        .eq('academic_year', _myYear as Object)
        .eq('speciality_id', _mySpecialityId as Object)
        .order('semester')
        .order('name');

    List<Map<String, dynamic>> modules = List<Map<String, dynamic>>.from(specialityRows as List);

    if (modules.isEmpty && _myDomainId != null) {
      final domainRows = await _supabase
          .from('study_modules')
          .select('id, name, semester, ue_category, study_resources(count)')
          .eq('academic_year', _myYear as Object)
          .eq('domain_id', _myDomainId as Object)
          .order('semester')
          .order('name');
      modules = List<Map<String, dynamic>>.from(domainRows as List);
    }

    if (!mounted) return;
    setState(() {
      _modules = modules;
      _loading = false;
    });
  }
'@
$lib_edit3_new = @'
  // Keyed by mode + speciality/year, so switching Browse-all <-> mine, or
  // the student's own speciality/year changing, naturally lands on a
  // different cache entry instead of needing manual invalidation.
  String get _modulesCacheKey =>
      _browsingAll ? 'library_modules_all' : 'library_modules_${_mySpecialityId}_$_myYear';

  // Cache-once: modules and their resource counts don't change often
  // enough to justify hitting Supabase every time a student opens
  // Library. Once cached, we trust it until the user pulls to refresh
  // or uploads a resource (see openUpload's forceRefresh) -- not daily,
  // not on every screen open.
  Future<void> _loadModules({bool forceRefresh = false}) async {
    final cacheKey = _modulesCacheKey;

    if (!forceRefresh) {
      final cached = await CachedFetch.readCache(cacheKey);
      if (cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _modules = cached;
          _loading = false;
        });
        return;
      }
    }

    List<Map<String, dynamic>> modules;

    if (_browsingAll) {
      final data = await _supabase
          .from('study_modules')
          .select('id, name, semester, ue_category, study_resources(count)')
          .order('semester')
          .order('name');
      modules = List<Map<String, dynamic>>.from(data as List);
    } else {
      // Prefer speciality-specific modules over domain-wide ones for this
      // year. Some specialities (e.g. Arabic Literature, Journalism &
      // Communication) have their own correct L1 content even though most
      // of their domain shares one L1 -- if speciality-scoped rows exist
      // for this year, domain-wide rows must NOT also be shown, or the
      // student sees both the right and the wrong curriculum stacked
      // together.
      final specialityRows = await _supabase
          .from('study_modules')
          .select('id, name, semester, ue_category, study_resources(count)')
          .eq('academic_year', _myYear as Object)
          .eq('speciality_id', _mySpecialityId as Object)
          .order('semester')
          .order('name');

      modules = List<Map<String, dynamic>>.from(specialityRows as List);

      if (modules.isEmpty && _myDomainId != null) {
        final domainRows = await _supabase
            .from('study_modules')
            .select('id, name, semester, ue_category, study_resources(count)')
            .eq('academic_year', _myYear as Object)
            .eq('domain_id', _myDomainId as Object)
            .order('semester')
            .order('name');
        modules = List<Map<String, dynamic>>.from(domainRows as List);
      }
    }

    await CachedFetch.writeCache(cacheKey, modules);

    if (!mounted) return;
    setState(() {
      _modules = modules;
      _loading = false;
    });
  }
'@

$lib_edit4_old = @'
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
'@
$lib_edit4_new = @'
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _load(forceRefresh: true),
'@

Patch-File $libPath @(
    @{ Old = $lib_edit1_old; New = $lib_edit1_new },
    @{ Old = $lib_edit2_old; New = $lib_edit2_new },
    @{ Old = $lib_edit3_old; New = $lib_edit3_new },
    @{ Old = $lib_edit4_old; New = $lib_edit4_new }
)

# =========================================================
# 2) module_screen.dart
# =========================================================
$modPath = "C:\kampuslink\lib\features\library\module_screen.dart"

$mod_edit1_old = @'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import 'upload_resource_screen.dart';
import 'resource_viewer_screen.dart';
'@
$mod_edit1_new = @'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/cached_fetch.dart';
import 'upload_resource_screen.dart';
import 'resource_viewer_screen.dart';
'@

$mod_edit2_old = @'
  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _supabase
        .from('study_resources')
        .select()
        .eq('module_id', widget.moduleId);
    if (!mounted) return;
    final resources = List<Map<String, dynamic>>.from(data as List);
    resources.sort((a, b) {
      final typeA = _typeOrder[a['resource_type'] as String] ?? 99;
      final typeB = _typeOrder[b['resource_type'] as String] ?? 99;
      if (typeA != typeB) return typeA.compareTo(typeB);
      final upvoteA = a['upvote_count'] as int? ?? 0;
      final upvoteB = b['upvote_count'] as int? ?? 0;
      return upvoteB.compareTo(upvoteA);
    });
    setState(() {
      _resources = resources;
      _loading = false;
    });
  }
'@
$mod_edit2_new = @'
  String get _cacheKey => 'module_resources_${widget.moduleId}';

  // Cache-once, not cache-first-then-refresh: once we have resources for
  // this module cached, we trust them and skip Supabase entirely on
  // future opens. Only a genuinely empty cache or an explicit pull-to-
  // refresh (forceRefresh: true) hits the network. This is deliberate --
  // module content doesn't change often enough to justify re-fetching
  // every time a student opens a module they've already seen.
  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);

    if (!forceRefresh) {
      final cached = await CachedFetch.readCache(_cacheKey);
      if (cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _resources = cached;
          _loading = false;
        });
        return;
      }
    }

    final data = await _supabase
        .from('study_resources')
        .select()
        .eq('module_id', widget.moduleId);
    if (!mounted) return;
    final resources = List<Map<String, dynamic>>.from(data as List);
    resources.sort((a, b) {
      final typeA = _typeOrder[a['resource_type'] as String] ?? 99;
      final typeB = _typeOrder[b['resource_type'] as String] ?? 99;
      if (typeA != typeB) return typeA.compareTo(typeB);
      final upvoteA = a['upvote_count'] as int? ?? 0;
      final upvoteB = b['upvote_count'] as int? ?? 0;
      return upvoteB.compareTo(upvoteA);
    });
    await CachedFetch.writeCache(_cacheKey, resources);
    setState(() {
      _resources = resources;
      _loading = false;
    });
  }
'@

$mod_edit3_old = @'
    ).then((added) {
      if (added == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.moduleName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _resources.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _resources.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ResourceCard(
                      resource: _resources[i],
                      trustColor: _trustColor(_resources[i]['trust_label'] as String),
                      typeLabel: _typeLabel(_resources[i]['resource_type'] as String),
                      onTap: () => _openResource(_resources[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
'@
$mod_edit3_new = @'
    ).then((added) {
      if (added == true) _load(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.moduleName)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _resources.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () => _load(forceRefresh: true),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _resources.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _ResourceCard(
                          resource: _resources[i],
                          trustColor: _trustColor(_resources[i]['trust_label'] as String),
                          typeLabel: _typeLabel(_resources[i]['resource_type'] as String),
                          onTap: () => _openResource(_resources[i]),
                        ),
                      ),
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
'@

Patch-File $modPath @(
    @{ Old = $mod_edit1_old; New = $mod_edit1_new },
    @{ Old = $mod_edit2_old; New = $mod_edit2_new },
    @{ Old = $mod_edit3_old; New = $mod_edit3_new }
)

# =========================================================
# 3) upload_resource_screen.dart
# =========================================================
$uploadPath = "C:\kampuslink\lib\features\library\upload_resource_screen.dart"

$up_edit1_old = @'
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Library')),
      body: _prefillLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
'@
$up_edit1_new = @'
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Library')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _prefillLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : ListView(
              padding: const EdgeInsets.all(20),
              children: [
'@

$up_edit2_old = @'
                      : const Text('Add to Library'),
                ),
              ],
            ),
    );
  }
'@
$up_edit2_new = @'
                      : const Text('Add to Library'),
                ),
              ],
            ),
        ),
      ),
    );
  }
'@

Patch-File $uploadPath @(
    @{ Old = $up_edit1_old; New = $up_edit1_new },
    @{ Old = $up_edit2_old; New = $up_edit2_new }
)

Write-Host "All files patched. Running flutter analyze..." -ForegroundColor Cyan
cd C:\kampuslink
flutter analyze