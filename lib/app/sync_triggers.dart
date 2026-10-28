import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_repository.dart';
import '../core/connectivity/connectivity.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../data/learning/feed_queue_provider.dart';
import '../data/reminders/reminder_controller.dart';
import '../data/sync/sync_controller.dart';
import 'router.dart';

/// MASTER_PLAN 7.4: sync at start, on resume, when the network comes back,
/// right after sign-in, when Supabase is ready (it starts in the
/// background) and every 15 minutes while the app is open. Going to the
/// background saves the next Home posts for an instant next start and
/// re-plans the study reminders.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _reminders;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync();
      // Reminders start a moment after the first frame (never before Home).
      _reminders = Timer(const Duration(seconds: 1), _startReminders);
    });
  }

  void _startReminders() {
    if (!mounted || !ref.read(isSignedInProvider)) {
      return;
    }
    unawaited(ref.read(reminderControllerProvider.notifier).start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reminders?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
      if (mounted && ref.read(isSignedInProvider)) {
        unawaited(ref.read(reminderControllerProvider.notifier).appOpened());
      }
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _saveFeed();
    }
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  void _saveFeed() {
    if (!mounted || !ref.read(isSignedInProvider)) {
      return;
    }
    unawaited(ref.read(feedQueueProvider.notifier).saveSnapshot());
    // Studied today -> no reminder today; new due-card count in the text.
    unawaited(ref.read(reminderControllerProvider.notifier).refreshPlan());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (previous == false && next) {
        _sync();
      }
    });
    ref.listen<bool>(isSignedInProvider, (previous, next) {
      if (previous != true && next) {
        _sync();
        _startReminders();
      }
      if (previous == true && !next) {
        unawaited(ref.read(reminderNotifierProvider).cancelAll());
      }
    });
    ref.listen(syncControllerProvider.select((s) => s.lastSyncedAt), (
      previous,
      next,
    ) {
      if (next != null && previous != next) {
        unawaited(
          ref.read(reminderControllerProvider.notifier).syncWithServer(),
        );
      }
    });
    // A tap on a study reminder (or Start): the 10-minute review session.
    ref.listen<int>(reminderLaunchProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        ref.read(routerProvider).push('/review');
      }
    });
    ref.listen(supabaseClientProvider, (previous, next) {
      if (previous == null && next != null) {
        _sync();
      }
    });
    return widget.child;
  }
}
