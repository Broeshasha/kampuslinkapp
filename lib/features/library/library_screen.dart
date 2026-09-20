import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/cached_fetch.dart';
import 'module_screen.dart';
import 'upload_resource_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _modules = [];
  bool _browsingAll = false;

  int? _mySpecialityId;
  int? _myDomainId;
  String? _myYear;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

    try {
      final userId = _supabase.auth.currentUser!.id;

      final cached = await CachedFetch.readCacheMap('my_profile');
      Map<String, dynamic> profile;
      if (cached != null) {
        profile = cached;
      } else {
        profile = await _supabase
            .rpc('get_my_profile', params: {'viewer_id': userId})
            .single()
            .timeout(const Duration(seconds: 8));
      }

      final specialityId = profile['speciality_id'] as int?;
      final year = profile['academic_year'] as String?;

      if (specialityId == null || year == null) {
        setState(() {
          _loading = false;
          _modules = [];
        });
        return;
      }

      final speciality = await _supabase
          .from('specialities')
          .select('domain_id')
          .eq('id', specialityId)
          .maybeSingle();
      final domainId = speciality?['domain_id'] as int?;

      _mySpecialityId = specialityId;
      _myDomainId = domainId;
      _myYear = year;

      await _loadModules();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load your library. Pull down to try again.';
          _loading = false;
        });
      }
    }
  }

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

  int _resourceCount(Map<String, dynamic> module) {
    final resources = module['study_resources'] as List?;
    if (resources == null || resources.isEmpty) return 0;
    return (resources.first['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _browsingAll ? 'All modules' : 'Your modules',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _browsingAll = !_browsingAll);
                      _loadModules();
                    },
                    child: Text(_browsingAll ? 'Show mine' : 'Browse all'),
                  ),
                ],
              ),
            ),
          ),
          if (_modules.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _browsingAll
                        ? 'No modules found.'
                        : 'Nothing set up for your year yet -- try Browse all.',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList.separated(
                itemCount: _modules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final module = _modules[i];
                  final count = _resourceCount(module);
                  return _ModuleCard(
                    name: module['name'] as String,
                    semester: module['semester'] as int?,
                    resourceCount: count,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ModuleScreen(
                            moduleId: module['id'] as int,
                            moduleName: module['name'] as String,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String name;
  final int? semester;
  final int resourceCount;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.name,
    required this.semester,
    required this.resourceCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      semester != null ? 'Semester $semester' : 'Annual',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (resourceCount == 0)
                const Text('Empty', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.official.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$resourceCount',
                    style: const TextStyle(color: AppColors.official, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}