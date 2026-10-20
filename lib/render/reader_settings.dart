import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/locale_controller.dart';

/// CONTENT_FORMAT 5.8: 3 reader text sizes, remembered on the phone.
const readerScales = [0.9, 1.0, 1.2];
const _prefsKey = 'reader_scale_step';

double readerScale(int step) =>
    readerScales[step.clamp(0, readerScales.length - 1)];

class ReaderScaleController extends Notifier<int> {
  @override
  int build() => (ref.read(sharedPrefsProvider).getInt(_prefsKey) ?? 1).clamp(
    0,
    readerScales.length - 1,
  );

  Future<void> setStep(int step) async {
    state = step.clamp(0, readerScales.length - 1);
    await ref.read(sharedPrefsProvider).setInt(_prefsKey, state);
  }
}

final readerScaleStepProvider = NotifierProvider<ReaderScaleController, int>(
  ReaderScaleController.new,
);
