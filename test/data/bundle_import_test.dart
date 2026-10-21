import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/bundle/bundle_importer.dart';
import 'package:kampuslink/data/db/app_database.dart';

Map<String, dynamic> bundle({
  int version = 1,
  int schema = 2,
  int lessonCount = 2,
}) => {
  'schema_version': schema,
  'module': {
    'id': 842,
    'name': 'Chimie minerale',
    'semester': 3,
    'ue_category': 'UEF',
    'academic_year': 'L2',
  },
  'version': version,
  'languages': ['fr', 'ar'],
  'generated_at': '2026-10-19T10:00:00Z',
  'lessons': [
    for (var i = 1; i <= lessonCount; i++)
      {
        'id': 100 + i,
        'position': i,
        'source_lang': 'fr',
        'unit': {
          'ref': 'ch2',
          'number': 2,
          'title': {'fr': 'Les oxydes'},
        },
        'estimated_minutes': 8,
        'i18n': {
          'fr': {
            'title': 'Lecon $i',
            'summary': 's',
            'blocks': [
              {'id': 'b1', 'type': 'paragraph'},
            ],
          },
        },
        'cards': [
          {
            'id': 1000 + i,
            'position': 1,
            'i18n': {
              'fr': {'front': 'Q', 'back': 'A'},
            },
          },
        ],
        'questions': [
          {
            'id': 2000 + i,
            'kind': 'mcq',
            'correct_index': 1,
            'position': 1,
            'i18n': {
              'fr': {
                'prompt': 'P',
                'options': ['a', 'b'],
                'explanation': 'e',
              },
            },
          },
        ],
        'resources': [
          {'resource_id': 7, 'role': 'source'},
        ],
      },
  ],
  'resources': [
    {
      'id': 7,
      'type': 'cours',
      'format': 'pdf',
      'title': 'Cours',
      'file_urls': ['https://files.kampus-link.com/x.pdf'],
      'trust_label': 'official',
      'size_bytes': 1234,
      'origin': 'admin',
      'created_at': '2026-10-01T00:00:00Z',
    },
  ],
  'glossary': [
    {
      'id': 1,
      'fr': 'oxyde',
      'ar': '\u0623\u0643\u0633\u064a\u062f',
      'en': 'oxide',
      'definition': {'fr': 'def'},
      'note': null,
    },
  ],
};

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<ModuleRow> module842() =>
      (db.select(db.modules)..where((t) => t.id.equals(842))).getSingle();

  test('imports a module bundle into the local tables', () async {
    await BundleImporter(db).importBundle(bundle());
    expect(await db.select(db.lessons).get(), hasLength(2));
    expect(await db.select(db.cards).get(), hasLength(2));
    expect(await db.select(db.questions).get(), hasLength(2));
    expect(await db.select(db.resources).get(), hasLength(1));
    expect(await db.select(db.glossaryEntries).get(), hasLength(1));
    final m = await module842();
    expect(m.localVersion, 1);
    expect(m.languages, 'fr,ar');
    expect(m.lessonCount, 2);
  });

  test('a newer bundle replaces the module content, no leftovers', () async {
    final importer = BundleImporter(db);
    await importer.importBundle(bundle());
    await importer.importBundle(bundle(version: 2, lessonCount: 1));
    expect(await db.select(db.lessons).get(), hasLength(1));
    expect(await db.select(db.cards).get(), hasLength(1));
    expect((await module842()).localVersion, 2);
  });

  test(
    'a bundle from a newer schema is refused and old content kept',
    () async {
      final importer = BundleImporter(db);
      await importer.importBundle(bundle());
      await expectLater(
        importer.importBundle(bundle(version: 3, schema: 4)),
        throwsA(isA<UnsupportedBundleSchema>()),
      );
      expect(await db.select(db.lessons).get(), hasLength(2));
      expect((await module842()).localVersion, 1);
    },
  );
}
