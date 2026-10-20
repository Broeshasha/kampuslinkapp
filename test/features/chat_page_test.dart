import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/core/connectivity/connectivity.dart';
import 'package:kampuslink/core/errors/app_failure.dart';
import 'package:kampuslink/core/l10n/locale_controller.dart';
import 'package:kampuslink/core/theme/app_theme.dart';
import 'package:kampuslink/data/chat/chat_providers.dart';
import 'package:kampuslink/data/chat/chat_repository.dart';
import 'package:kampuslink/data/db/app_database.dart';
import 'package:kampuslink/data/providers.dart';
import 'package:kampuslink/features/chat/chat_page.dart';
import 'package:kampuslink/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> message(String id, String body, {bool mine = false}) => {
  'id': id,
  'user_id': mine ? 'me' : 'u2',
  'username': 'amina_mines_l2',
  'body': body,
  'lang': mine ? 'und' : 'ar',
  'translated_body': mine ? null : 'Who has the TD 3 solution for exercise 2?',
  'translated_lang': mine ? null : 'en',
  'created_at': DateTime.utc(2026, 10, 20, 10, id.length).toIso8601String(),
  'is_mine': mine,
};

void main() {
  for (final size in const [Size(320, 568), Size(412, 915)]) {
    testWidgets('chat fits ${size.width.toInt()} wide at 1.5x text, offline', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final offline = ChatRepository(
        db,
        fetch: (m, b) async => throw const OfflineFailure(),
        post: (m, body, lang, id) async => throw const OfflineFailure(),
      );
      await tester.runAsync(() async {
        final seed = ChatRepository(
          db,
          fetch: (m, b) async => [
            message(
              'a1',
              '\u0645\u0646 \u0639\u0646\u062f\u0647 \u062d\u0644 '
                  '\u0627\u0644\u062a\u0645\u0631\u064a\u0646 2 '
                  '\u0645\u0646 TD 3\u061f',
            ),
            message(
              'b22',
              'A very long message without spaces: '
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              mine: true,
            ),
          ],
          post: (m, body, lang, id) async => throw const OfflineFailure(),
        );
        await seed.refresh(7);
        await seed.queue(7, 'Sent while offline');
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
            appDatabaseProvider.overrideWithValue(db),
            chatRepositoryProvider.overrideWithValue(offline),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const ChatPage(moduleId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sending...'), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
  }
}
