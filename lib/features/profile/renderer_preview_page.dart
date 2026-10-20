import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../render/demo_lesson.dart';
import '../../render/lesson_view.dart';
import '../../render/reader_settings.dart';
import '../../render/source_adapter.dart';

/// DEBUG ONLY: the demo lesson in FR / AR / EN at the 3 reader sizes.
class RendererPreviewPage extends ConsumerStatefulWidget {
  const RendererPreviewPage({super.key});

  @override
  ConsumerState<RendererPreviewPage> createState() =>
      _RendererPreviewPageState();
}

class _RendererPreviewPageState extends ConsumerState<RendererPreviewPage> {
  String _lang = 'fr';

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(readerScaleStepProvider);
    final blocks = blocksFromSourceChapter(demoChapter, _lang);
    return Scaffold(
      appBar: AppBar(title: const Text('Renderer preview (debug)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpace.sm),
            child: Wrap(
              spacing: KSpace.sm,
              runSpacing: KSpace.sm,
              alignment: WrapAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fr', label: Text('FR')),
                    ButtonSegment(value: 'ar', label: Text('AR')),
                    ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: {_lang},
                  onSelectionChanged: (s) => setState(() => _lang = s.first),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('A-')),
                    ButtonSegment(value: 1, label: Text('A')),
                    ButtonSegment(value: 2, label: Text('A+')),
                  ],
                  selected: {step},
                  onSelectionChanged: (s) => ref
                      .read(readerScaleStepProvider.notifier)
                      .setStep(s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: LessonView(
              blocks: blocks,
              language: _lang,
              scale: readerScale(step),
            ),
          ),
        ],
      ),
    );
  }
}
