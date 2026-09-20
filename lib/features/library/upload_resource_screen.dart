import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/algeria_universities.dart';
import '../../core/config/upload_service.dart';
import '../../core/config/cached_fetch.dart';
import '../../core/widgets/searchable_picker.dart';

class UploadResourceScreen extends StatefulWidget {
  final int? preselectedModuleId;
  final String? preselectedModuleName;

  const UploadResourceScreen({
    super.key,
    this.preselectedModuleId,
    this.preselectedModuleName,
  });

  @override
  State<UploadResourceScreen> createState() => _UploadResourceScreenState();
}

const _resourceTypes = {
  'cours': 'Cours',
  'td': 'TD',
  'exercices_corriges': 'Exercices Corrigés',
  'exam': 'Exam',
  'notes': 'Notes',
};

const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

class _UploadResourceScreenState extends State<UploadResourceScreen> {
  final _supabase = Supabase.instance.client;

  String _selectedType = 'cours';
  Speciality? _selectedSpeciality;
  String? _selectedYear;
  int? _selectedSemester;
  Map<String, dynamic>? _selectedModule;
  List<PlatformFile> _pickedFiles = [];
  bool _uploading = false;
  bool _prefillLoading = true;

  bool get _isPreselectedModule => widget.preselectedModuleId != null;

  @override
  void initState() {
    super.initState();
    if (_isPreselectedModule) {
      _selectedModule = {
        'id': widget.preselectedModuleId,
        'name': widget.preselectedModuleName,
      };
      _prefillLoading = false;
    } else {
      _prefillFromProfile();
    }
  }

  Future<void> _prefillFromProfile() async {
    try {
      final cached = await CachedFetch.readCacheMap('my_profile');
      final specialityId = cached?['speciality_id'] as int?;
      final year = cached?['academic_year'] as String?;
      if (specialityId != null) {
        final match = algeriaSpecialities.where((s) => s.id == specialityId);
        if (match.isNotEmpty) {
          setState(() {
            _selectedSpeciality = match.first;
            _selectedYear = year;
          });
        }
      }
    } catch (_) {
      // No prefill available -- user just picks manually, not an error.
    } finally {
      if (mounted) setState(() => _prefillLoading = false);
    }
  }

  List<String> _yearOptionsFor(Speciality s) {
    if (s.yearSystem == 'unified') {
      return List.generate(s.maxYear, (i) => 'Year ${i + 1}');
    }
    final years = <String>[];
    for (var i = 1; i <= s.maxYear && i <= 3; i++) {
      years.add('L$i');
    }
    for (var i = 1; i <= (s.maxYear - 3); i++) {
      years.add('M$i');
    }
    return years;
  }

  bool get _isUnifiedYearSystem => _selectedSpeciality?.yearSystem == 'unified';

  Future<void> _pickModule() async {
    if (_selectedSpeciality == null || _selectedYear == null) return;
    if (!_isUnifiedYearSystem && _selectedSemester == null) return;

    final speciality = await _supabase
        .from('specialities')
        .select('domain_id')
        .eq('id', _selectedSpeciality!.id)
        .maybeSingle();
    final domainId = speciality?['domain_id'] as int?;

    // Prefer speciality-specific modules over domain-wide ones -- some
    // specialities have their own correct content even though most of
    // their domain shares one set, and showing both stacked together is
    // wrong even when the domain-wide set is usually fine.
    var specialityQuery = _supabase
        .from('study_modules')
        .select('id, name, semester')
        .eq('academic_year', _selectedYear as Object)
        .eq('speciality_id', _selectedSpeciality!.id);
    if (!_isUnifiedYearSystem) {
      specialityQuery = specialityQuery.or('semester.eq.$_selectedSemester,semester.is.null');
    }
    final specialityData = await specialityQuery.order('name');
    var modules = List<Map<String, dynamic>>.from(specialityData as List);

    if (modules.isEmpty && domainId != null) {
      var domainQuery = _supabase
          .from('study_modules')
          .select('id, name, semester')
          .eq('academic_year', _selectedYear as Object)
          .eq('domain_id', domainId);
      if (!_isUnifiedYearSystem) {
        domainQuery = domainQuery.or('semester.eq.$_selectedSemester,semester.is.null');
      }
      final domainData = await domainQuery.order('name');
      modules = List<Map<String, dynamic>>.from(domainData as List);
    }

    if (!mounted) return;
    final result = await SearchablePicker.show<Map<String, dynamic>>(
      context: context,
      title: 'Select the module',
      items: modules,
      labelBuilder: (m) => m['name'] as String,
    );
    if (result != null) setState(() => _selectedModule = result);
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty) return;
    setState(() => _pickedFiles = files);
  }

  bool get _canSubmit =>
      _selectedModule != null && _pickedFiles.isNotEmpty && !_uploading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _uploading = true);

    try {
      final allImages = _pickedFiles.every(
        (f) => _imageExtensions.contains((f.extension ?? '').toLowerCase()),
      );

      final urls = <String>[];
      for (final file in _pickedFiles) {
        final bytes = await file.readAsBytes();
        final url = await UploadService.upload(bytes, 'library', file.name);
        if (url == null) {
          throw Exception('Upload failed for ${file.name}');
        }
        urls.add(url);
      }

      if (urls.isEmpty) {
        throw Exception('No files were uploaded successfully.');
      }

      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('study_resources').insert({
        'module_id': _selectedModule!['id'],
        'uploader_id': userId,
        'resource_type': _selectedType,
        'trust_label': 'Community',
        'file_format': allImages ? 'image_set' : 'pdf',
        'file_urls': urls,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to the library.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Library')),
      body: _prefillLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _resourceTypes.entries.map((e) {
                    final selected = _selectedType == e.key;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedType = e.key),
                      selectedColor: AppColors.accent,
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                if (!_isPreselectedModule) ...[
                  const Text('Speciality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _pickerRow(
                    label: _selectedSpeciality?.name ?? 'Select a speciality',
                    onTap: () async {
                      final result = await SearchablePicker.show<Speciality>(
                        context: context,
                        title: 'Select speciality',
                        items: algeriaSpecialities,
                        labelBuilder: (s) => s.name,
                      );
                      if (result != null) {
                        setState(() {
                          _selectedSpeciality = result;
                          _selectedYear = null;
                          _selectedSemester = null;
                          _selectedModule = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_selectedSpeciality != null) ...[
                    const Text('Year', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _pickerRow(
                      label: _selectedYear ?? 'Select year',
                      onTap: () async {
                        final options = _yearOptionsFor(_selectedSpeciality!);
                        final result = await SearchablePicker.show<String>(
                          context: context,
                          title: 'Select year',
                          items: options,
                          labelBuilder: (y) => y,
                        );
                        if (result != null) {
                          setState(() {
                            _selectedYear = result;
                            _selectedSemester = null;
                            _selectedModule = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_selectedYear != null && !_isUnifiedYearSystem) ...[
                    const Text('Semester', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [1, 2].map((s) {
                        final selected = _selectedSemester == s;
                        return ChoiceChip(
                          label: Text('Semester $s'),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _selectedSemester = s;
                            _selectedModule = null;
                          }),
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text('Module', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _pickerRow(
                    label: _selectedModule?['name'] as String? ?? 'Select module',
                    enabled: _selectedSpeciality != null &&
                        _selectedYear != null &&
                        (_isUnifiedYearSystem || _selectedSemester != null),
                    onTap: _pickModule,
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const Text('Module', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    widget.preselectedModuleName ?? '',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                ],

                const Text('File(s)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                  'PDF, Word, PowerPoint, or multiple photos of pages (in order)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_pickedFiles.isEmpty
                      ? 'Choose file(s)'
                      : '${_pickedFiles.length} file(s) selected'),
                ),
                if (_pickedFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _pickedFiles
                          .map((f) => Chip(
                                label: Text(f.name, overflow: TextOverflow.ellipsis),
                                backgroundColor: AppColors.surface,
                                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add to Library'),
                ),
              ],
            ),
    );
  }

  Widget _pickerRow({required String label, required VoidCallback onTap, bool enabled = true}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: enabled ? Colors.white : AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}