import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = the stories bar is shown at the top of Home.
class StoriesBarVisible extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool visible) {
    if (state != visible) state = visible;
  }
}

final storiesBarVisibleProvider = NotifierProvider<StoriesBarVisible, bool>(
  StoriesBarVisible.new,
);

/// Wraps the Home feed: swiping forward (down the feed) hides the stories
/// bar, swiping back shows it, and it is shown again at the top of the feed
/// and every time the student comes back to the Home tab.
class StoriesScrollWatcher extends ConsumerStatefulWidget {
  const StoriesScrollWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StoriesScrollWatcher> createState() =>
      _StoriesScrollWatcherState();
}

class _StoriesScrollWatcherState extends ConsumerState<StoriesScrollWatcher> {
  bool _active = true;

  void _set(bool visible) =>
      ref.read(storiesBarVisibleProvider.notifier).set(visible);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab bar keeps other tabs alive but turns their tickers off:
    // tickers back on = the student came back to Home.
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _set(true);
      });
    }
    _active = active;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis != Axis.vertical) return false;
        if (n.metrics.pixels <= n.metrics.minScrollExtent) {
          _set(true);
        } else if (n.direction == ScrollDirection.reverse) {
          _set(false);
        } else if (n.direction == ScrollDirection.forward) {
          _set(true);
        }
        return false;
      },
      child: widget.child,
    );
  }
}
