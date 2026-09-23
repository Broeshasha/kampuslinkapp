import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/cached_fetch.dart';
import 'upload_resource_screen.dart';
import 'resource_viewer_screen.dart';

class ModuleScreen extends StatefulWidget {
  final int moduleId;
  final String moduleName;

  const ModuleScreen({super.key, required this.moduleId, required this.moduleName});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _resources = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static const _typeOrder = {
    'cours': 0,
    'td': 1,
    'exercices_corriges': 2,
    'exam': 3,
    'notes': 4,
    'memoire': 5,
  };

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

  Color _trustColor(String label) {
    switch (label) {
      case 'Official':
        return AppColors.official;
      case 'Verified':
        return AppColors.verified;
      case 'Community':
        return AppColors.community;
      default:
        return AppColors.textSecondary;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'cours':
        return 'Cours';
      case 'td':
        return 'TD';
      case 'exercices_corriges':
        return 'Exercices Corrigés';
      case 'exam':
        return 'Exam';
      case 'notes':
        return 'Notes';
      case 'memoire':
        return 'Mémoire';
      default:
        return type;
    }
  }

  void _openResource(Map<String, dynamic> resource) {
    final fileUrls = List<String>.from(resource['file_urls'] as List);
    if (fileUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This resource has no file attached.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResourceViewerScreen(
          title: _typeLabel(resource['resource_type'] as String),
          fileFormat: resource['file_format'] as String,
          fileUrls: fileUrls,
        ),
      ),
    );
  }

  void _uploadToThisModule() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadResourceScreen(
          preselectedModuleId: widget.moduleId,
          preselectedModuleName: widget.moduleName,
        ),
      ),
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
        backgroundColor: AppColors.accent,
        onPressed: _uploadToThisModule,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No resources yet for this module.',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to add one.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadToThisModule,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Add a resource'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final Map<String, dynamic> resource;
  final Color trustColor;
  final String typeLabel;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.resource,
    required this.trustColor,
    required this.typeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final downloadCount = resource['download_count'] as int? ?? 0;
    final upvoteCount = resource['upvote_count'] as int? ?? 0;
    final trustLabel = resource['trust_label'] as String;

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
                  color: trustColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_outlined, color: trustColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(typeLabel, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: trustColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(trustLabel, style: TextStyle(color: trustColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.download_outlined, color: AppColors.textSecondary, size: 12),
                        const SizedBox(width: 2),
                        Text('$downloadCount', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_upward_rounded, color: AppColors.textSecondary, size: 12),
                        const SizedBox(width: 2),
                        Text('$upvoteCount', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}