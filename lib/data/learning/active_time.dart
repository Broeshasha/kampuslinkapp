/// MASTER_PLAN 7.7 study timer: counts only ACTIVE time (app in the
/// foreground and a touch or scroll in the last 60 s). Call [tick] every
/// second; every [flushEvery] seconds the time is handed to [onFlush].
class ActiveTimeCounter {
  ActiveTimeCounter({
    required this.onFlush,
    this.idle = const Duration(seconds: 60),
    this.flushEvery = 30,
  });

  final void Function(int seconds) onFlush;
  final Duration idle;
  final int flushEvery;

  DateTime? _lastTouch;
  DateTime? _lastTick;
  int _pending = 0;
  bool _foreground = true;

  int get pending => _pending;

  void touch(DateTime now) => _lastTouch = now;

  void tick(DateTime now) {
    final last = _lastTick;
    _lastTick = now;
    final touched = _lastTouch;
    if (!_foreground || last == null || touched == null) return;
    if (now.difference(touched) > idle) return;
    // A long gap (phone asleep) never counts as study.
    _pending += now.difference(last).inSeconds.clamp(0, 5);
    if (_pending >= flushEvery) flush();
  }

  void setForeground(bool value) {
    _foreground = value;
    _lastTick = null;
    if (!value) flush();
  }

  void flush() {
    if (_pending <= 0) return;
    final seconds = _pending;
    _pending = 0;
    onFlush(seconds);
  }
}
