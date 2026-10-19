import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real instance is injected in main() (loaded once, before runApp).
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

const supportedLanguageCodes = ['ar', 'fr', 'en'];
const fallbackLanguageCode = 'fr';
const _prefsKey = 'ui_language';

/// null = follow the phone (D-012). Otherwise the user's explicit choice.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final saved = ref.read(sharedPrefsProvider).getString(_prefsKey);
    if (saved != null && supportedLanguageCodes.contains(saved)) {
      return Locale(saved);
    }
    return null;
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;
    state = Locale(code);
    await ref.read(sharedPrefsProvider).setString(_prefsKey, code);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// D-012: first phone language that we support, else French.
Locale resolveLocale(List<Locale>? deviceLocales, Iterable<Locale> supported) {
  for (final locale in deviceLocales ?? const <Locale>[]) {
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return const Locale(fallbackLanguageCode);
}
