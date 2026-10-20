import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/locale_controller.dart';

const _prefsKey = 'theme_mode';

/// System (default, D-011), light or dark; remembered on the phone.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      switch (ref.read(sharedPrefsProvider).getString(_prefsKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString(_prefsKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
