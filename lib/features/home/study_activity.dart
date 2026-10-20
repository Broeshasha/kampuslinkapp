import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/result.dart';
import '../../data/learning/active_time.dart';
import '../../data/learning/progress_repository.dart';
import '../../data/providers.dart';

/// Wrap a study screen (feed, reader, quiz): counts ACTIVE time only and
/// logs it through the outbox (log_study_time) every 30 s and on pause.
class StudyActivity extends ConsumerStatefulWidget {
  const StudyActivity({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StudyActivity> createState() => _StudyActivityState();
}

class _StudyActivityState extends ConsumerState<StudyActivity> {
  late final ProgressRepository _progress;
  late final ActiveTimeCounter _counter;
  late final AppLifecycleListener _life;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _progress = ref.read(progressRepositoryProvider);
    _counter = ActiveTimeCounter(
      onFlush: (seconds) =>
          unawaited(guard(() => _progress.logStudySeconds(seconds))),
    );
    _counter.touch(DateTime.now());
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _counter.tick(DateTime.now()),
    );
    _life = AppLifecycleListener(
      onHide: () => _counter.setForeground(false),
      onShow: () => _counter.setForeground(true),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _counter.flush();
    _life.dispose();
    super.dispose();
  }

  void _touch(PointerEvent _) => _counter.touch(DateTime.now());

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _touch,
    onPointerMove: _touch,
    onPointerSignal: _touch,
    child: widget.child,
  );
}
