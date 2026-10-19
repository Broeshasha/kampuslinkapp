// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ModulesTable extends Modules with TableInfo<$ModulesTable, ModuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semesterMeta = const VerificationMeta(
    'semester',
  );
  @override
  late final GeneratedColumn<int> semester = GeneratedColumn<int>(
    'semester',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ueCategoryMeta = const VerificationMeta(
    'ueCategory',
  );
  @override
  late final GeneratedColumn<String> ueCategory = GeneratedColumn<String>(
    'ue_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _academicYearMeta = const VerificationMeta(
    'academicYear',
  );
  @override
  late final GeneratedColumn<String> academicYear = GeneratedColumn<String>(
    'academic_year',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lessonCountMeta = const VerificationMeta(
    'lessonCount',
  );
  @override
  late final GeneratedColumn<int> lessonCount = GeneratedColumn<int>(
    'lesson_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lessonsDoneMeta = const VerificationMeta(
    'lessonsDone',
  );
  @override
  late final GeneratedColumn<int> lessonsDone = GeneratedColumn<int>(
    'lessons_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _resourceCountMeta = const VerificationMeta(
    'resourceCount',
  );
  @override
  late final GeneratedColumn<int> resourceCount = GeneratedColumn<int>(
    'resource_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _languagesMeta = const VerificationMeta(
    'languages',
  );
  @override
  late final GeneratedColumn<String> languages = GeneratedColumn<String>(
    'languages',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    semester,
    ueCategory,
    academicYear,
    serverVersion,
    localVersion,
    lessonCount,
    lessonsDone,
    resourceCount,
    languages,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'modules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('semester')) {
      context.handle(
        _semesterMeta,
        semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta),
      );
    }
    if (data.containsKey('ue_category')) {
      context.handle(
        _ueCategoryMeta,
        ueCategory.isAcceptableOrUnknown(data['ue_category']!, _ueCategoryMeta),
      );
    }
    if (data.containsKey('academic_year')) {
      context.handle(
        _academicYearMeta,
        academicYear.isAcceptableOrUnknown(
          data['academic_year']!,
          _academicYearMeta,
        ),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('lesson_count')) {
      context.handle(
        _lessonCountMeta,
        lessonCount.isAcceptableOrUnknown(
          data['lesson_count']!,
          _lessonCountMeta,
        ),
      );
    }
    if (data.containsKey('lessons_done')) {
      context.handle(
        _lessonsDoneMeta,
        lessonsDone.isAcceptableOrUnknown(
          data['lessons_done']!,
          _lessonsDoneMeta,
        ),
      );
    }
    if (data.containsKey('resource_count')) {
      context.handle(
        _resourceCountMeta,
        resourceCount.isAcceptableOrUnknown(
          data['resource_count']!,
          _resourceCountMeta,
        ),
      );
    }
    if (data.containsKey('languages')) {
      context.handle(
        _languagesMeta,
        languages.isAcceptableOrUnknown(data['languages']!, _languagesMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      semester: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}semester'],
      ),
      ueCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ue_category'],
      ),
      academicYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}academic_year'],
      ),
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      lessonCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_count'],
      )!,
      lessonsDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lessons_done'],
      )!,
      resourceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resource_count'],
      )!,
      languages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}languages'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
    );
  }

  @override
  $ModulesTable createAlias(String alias) {
    return $ModulesTable(attachedDatabase, alias);
  }
}

class ModuleRow extends DataClass implements Insertable<ModuleRow> {
  final int id;
  final String name;
  final int? semester;
  final String? ueCategory;
  final String? academicYear;
  final int serverVersion;
  final int localVersion;
  final int lessonCount;
  final int lessonsDone;
  final int resourceCount;
  final String languages;
  final DateTime? downloadedAt;
  const ModuleRow({
    required this.id,
    required this.name,
    this.semester,
    this.ueCategory,
    this.academicYear,
    required this.serverVersion,
    required this.localVersion,
    required this.lessonCount,
    required this.lessonsDone,
    required this.resourceCount,
    required this.languages,
    this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || semester != null) {
      map['semester'] = Variable<int>(semester);
    }
    if (!nullToAbsent || ueCategory != null) {
      map['ue_category'] = Variable<String>(ueCategory);
    }
    if (!nullToAbsent || academicYear != null) {
      map['academic_year'] = Variable<String>(academicYear);
    }
    map['server_version'] = Variable<int>(serverVersion);
    map['local_version'] = Variable<int>(localVersion);
    map['lesson_count'] = Variable<int>(lessonCount);
    map['lessons_done'] = Variable<int>(lessonsDone);
    map['resource_count'] = Variable<int>(resourceCount);
    map['languages'] = Variable<String>(languages);
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    return map;
  }

  ModulesCompanion toCompanion(bool nullToAbsent) {
    return ModulesCompanion(
      id: Value(id),
      name: Value(name),
      semester: semester == null && nullToAbsent
          ? const Value.absent()
          : Value(semester),
      ueCategory: ueCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(ueCategory),
      academicYear: academicYear == null && nullToAbsent
          ? const Value.absent()
          : Value(academicYear),
      serverVersion: Value(serverVersion),
      localVersion: Value(localVersion),
      lessonCount: Value(lessonCount),
      lessonsDone: Value(lessonsDone),
      resourceCount: Value(resourceCount),
      languages: Value(languages),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
    );
  }

  factory ModuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModuleRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      semester: serializer.fromJson<int?>(json['semester']),
      ueCategory: serializer.fromJson<String?>(json['ueCategory']),
      academicYear: serializer.fromJson<String?>(json['academicYear']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      lessonCount: serializer.fromJson<int>(json['lessonCount']),
      lessonsDone: serializer.fromJson<int>(json['lessonsDone']),
      resourceCount: serializer.fromJson<int>(json['resourceCount']),
      languages: serializer.fromJson<String>(json['languages']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'semester': serializer.toJson<int?>(semester),
      'ueCategory': serializer.toJson<String?>(ueCategory),
      'academicYear': serializer.toJson<String?>(academicYear),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'localVersion': serializer.toJson<int>(localVersion),
      'lessonCount': serializer.toJson<int>(lessonCount),
      'lessonsDone': serializer.toJson<int>(lessonsDone),
      'resourceCount': serializer.toJson<int>(resourceCount),
      'languages': serializer.toJson<String>(languages),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
    };
  }

  ModuleRow copyWith({
    int? id,
    String? name,
    Value<int?> semester = const Value.absent(),
    Value<String?> ueCategory = const Value.absent(),
    Value<String?> academicYear = const Value.absent(),
    int? serverVersion,
    int? localVersion,
    int? lessonCount,
    int? lessonsDone,
    int? resourceCount,
    String? languages,
    Value<DateTime?> downloadedAt = const Value.absent(),
  }) => ModuleRow(
    id: id ?? this.id,
    name: name ?? this.name,
    semester: semester.present ? semester.value : this.semester,
    ueCategory: ueCategory.present ? ueCategory.value : this.ueCategory,
    academicYear: academicYear.present ? academicYear.value : this.academicYear,
    serverVersion: serverVersion ?? this.serverVersion,
    localVersion: localVersion ?? this.localVersion,
    lessonCount: lessonCount ?? this.lessonCount,
    lessonsDone: lessonsDone ?? this.lessonsDone,
    resourceCount: resourceCount ?? this.resourceCount,
    languages: languages ?? this.languages,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
  );
  ModuleRow copyWithCompanion(ModulesCompanion data) {
    return ModuleRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      semester: data.semester.present ? data.semester.value : this.semester,
      ueCategory: data.ueCategory.present
          ? data.ueCategory.value
          : this.ueCategory,
      academicYear: data.academicYear.present
          ? data.academicYear.value
          : this.academicYear,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      lessonCount: data.lessonCount.present
          ? data.lessonCount.value
          : this.lessonCount,
      lessonsDone: data.lessonsDone.present
          ? data.lessonsDone.value
          : this.lessonsDone,
      resourceCount: data.resourceCount.present
          ? data.resourceCount.value
          : this.resourceCount,
      languages: data.languages.present ? data.languages.value : this.languages,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModuleRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('semester: $semester, ')
          ..write('ueCategory: $ueCategory, ')
          ..write('academicYear: $academicYear, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('localVersion: $localVersion, ')
          ..write('lessonCount: $lessonCount, ')
          ..write('lessonsDone: $lessonsDone, ')
          ..write('resourceCount: $resourceCount, ')
          ..write('languages: $languages, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    semester,
    ueCategory,
    academicYear,
    serverVersion,
    localVersion,
    lessonCount,
    lessonsDone,
    resourceCount,
    languages,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModuleRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.semester == this.semester &&
          other.ueCategory == this.ueCategory &&
          other.academicYear == this.academicYear &&
          other.serverVersion == this.serverVersion &&
          other.localVersion == this.localVersion &&
          other.lessonCount == this.lessonCount &&
          other.lessonsDone == this.lessonsDone &&
          other.resourceCount == this.resourceCount &&
          other.languages == this.languages &&
          other.downloadedAt == this.downloadedAt);
}

class ModulesCompanion extends UpdateCompanion<ModuleRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> semester;
  final Value<String?> ueCategory;
  final Value<String?> academicYear;
  final Value<int> serverVersion;
  final Value<int> localVersion;
  final Value<int> lessonCount;
  final Value<int> lessonsDone;
  final Value<int> resourceCount;
  final Value<String> languages;
  final Value<DateTime?> downloadedAt;
  const ModulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.semester = const Value.absent(),
    this.ueCategory = const Value.absent(),
    this.academicYear = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.lessonCount = const Value.absent(),
    this.lessonsDone = const Value.absent(),
    this.resourceCount = const Value.absent(),
    this.languages = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  });
  ModulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.semester = const Value.absent(),
    this.ueCategory = const Value.absent(),
    this.academicYear = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.lessonCount = const Value.absent(),
    this.lessonsDone = const Value.absent(),
    this.resourceCount = const Value.absent(),
    this.languages = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ModuleRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? semester,
    Expression<String>? ueCategory,
    Expression<String>? academicYear,
    Expression<int>? serverVersion,
    Expression<int>? localVersion,
    Expression<int>? lessonCount,
    Expression<int>? lessonsDone,
    Expression<int>? resourceCount,
    Expression<String>? languages,
    Expression<DateTime>? downloadedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (semester != null) 'semester': semester,
      if (ueCategory != null) 'ue_category': ueCategory,
      if (academicYear != null) 'academic_year': academicYear,
      if (serverVersion != null) 'server_version': serverVersion,
      if (localVersion != null) 'local_version': localVersion,
      if (lessonCount != null) 'lesson_count': lessonCount,
      if (lessonsDone != null) 'lessons_done': lessonsDone,
      if (resourceCount != null) 'resource_count': resourceCount,
      if (languages != null) 'languages': languages,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
    });
  }

  ModulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? semester,
    Value<String?>? ueCategory,
    Value<String?>? academicYear,
    Value<int>? serverVersion,
    Value<int>? localVersion,
    Value<int>? lessonCount,
    Value<int>? lessonsDone,
    Value<int>? resourceCount,
    Value<String>? languages,
    Value<DateTime?>? downloadedAt,
  }) {
    return ModulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      semester: semester ?? this.semester,
      ueCategory: ueCategory ?? this.ueCategory,
      academicYear: academicYear ?? this.academicYear,
      serverVersion: serverVersion ?? this.serverVersion,
      localVersion: localVersion ?? this.localVersion,
      lessonCount: lessonCount ?? this.lessonCount,
      lessonsDone: lessonsDone ?? this.lessonsDone,
      resourceCount: resourceCount ?? this.resourceCount,
      languages: languages ?? this.languages,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (semester.present) {
      map['semester'] = Variable<int>(semester.value);
    }
    if (ueCategory.present) {
      map['ue_category'] = Variable<String>(ueCategory.value);
    }
    if (academicYear.present) {
      map['academic_year'] = Variable<String>(academicYear.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (lessonCount.present) {
      map['lesson_count'] = Variable<int>(lessonCount.value);
    }
    if (lessonsDone.present) {
      map['lessons_done'] = Variable<int>(lessonsDone.value);
    }
    if (resourceCount.present) {
      map['resource_count'] = Variable<int>(resourceCount.value);
    }
    if (languages.present) {
      map['languages'] = Variable<String>(languages.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('semester: $semester, ')
          ..write('ueCategory: $ueCategory, ')
          ..write('academicYear: $academicYear, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('localVersion: $localVersion, ')
          ..write('lessonCount: $lessonCount, ')
          ..write('lessonsDone: $lessonsDone, ')
          ..write('resourceCount: $resourceCount, ')
          ..write('languages: $languages, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }
}

class $LessonsTable extends Lessons with TableInfo<$LessonsTable, LessonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _moduleIdMeta = const VerificationMeta(
    'moduleId',
  );
  @override
  late final GeneratedColumn<int> moduleId = GeneratedColumn<int>(
    'module_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceLangMeta = const VerificationMeta(
    'sourceLang',
  );
  @override
  late final GeneratedColumn<String> sourceLang = GeneratedColumn<String>(
    'source_lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitJsonMeta = const VerificationMeta(
    'unitJson',
  );
  @override
  late final GeneratedColumn<String> unitJson = GeneratedColumn<String>(
    'unit_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedMinutesMeta = const VerificationMeta(
    'estimatedMinutes',
  );
  @override
  late final GeneratedColumn<int> estimatedMinutes = GeneratedColumn<int>(
    'estimated_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _i18nJsonMeta = const VerificationMeta(
    'i18nJson',
  );
  @override
  late final GeneratedColumn<String> i18nJson = GeneratedColumn<String>(
    'i18n_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceLinksJsonMeta = const VerificationMeta(
    'resourceLinksJson',
  );
  @override
  late final GeneratedColumn<String> resourceLinksJson =
      GeneratedColumn<String>(
        'resource_links_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    moduleId,
    position,
    sourceLang,
    unitJson,
    estimatedMinutes,
    i18nJson,
    resourceLinksJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('module_id')) {
      context.handle(
        _moduleIdMeta,
        moduleId.isAcceptableOrUnknown(data['module_id']!, _moduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('source_lang')) {
      context.handle(
        _sourceLangMeta,
        sourceLang.isAcceptableOrUnknown(data['source_lang']!, _sourceLangMeta),
      );
    }
    if (data.containsKey('unit_json')) {
      context.handle(
        _unitJsonMeta,
        unitJson.isAcceptableOrUnknown(data['unit_json']!, _unitJsonMeta),
      );
    }
    if (data.containsKey('estimated_minutes')) {
      context.handle(
        _estimatedMinutesMeta,
        estimatedMinutes.isAcceptableOrUnknown(
          data['estimated_minutes']!,
          _estimatedMinutesMeta,
        ),
      );
    }
    if (data.containsKey('i18n_json')) {
      context.handle(
        _i18nJsonMeta,
        i18nJson.isAcceptableOrUnknown(data['i18n_json']!, _i18nJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_i18nJsonMeta);
    }
    if (data.containsKey('resource_links_json')) {
      context.handle(
        _resourceLinksJsonMeta,
        resourceLinksJson.isAcceptableOrUnknown(
          data['resource_links_json']!,
          _resourceLinksJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LessonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      moduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}module_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      sourceLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_lang'],
      ),
      unitJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_json'],
      ),
      estimatedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_minutes'],
      ),
      i18nJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}i18n_json'],
      )!,
      resourceLinksJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_links_json'],
      )!,
    );
  }

  @override
  $LessonsTable createAlias(String alias) {
    return $LessonsTable(attachedDatabase, alias);
  }
}

class LessonRow extends DataClass implements Insertable<LessonRow> {
  final int id;
  final int moduleId;
  final int position;
  final String? sourceLang;
  final String? unitJson;
  final int? estimatedMinutes;
  final String i18nJson;
  final String resourceLinksJson;
  const LessonRow({
    required this.id,
    required this.moduleId,
    required this.position,
    this.sourceLang,
    this.unitJson,
    this.estimatedMinutes,
    required this.i18nJson,
    required this.resourceLinksJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['module_id'] = Variable<int>(moduleId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || sourceLang != null) {
      map['source_lang'] = Variable<String>(sourceLang);
    }
    if (!nullToAbsent || unitJson != null) {
      map['unit_json'] = Variable<String>(unitJson);
    }
    if (!nullToAbsent || estimatedMinutes != null) {
      map['estimated_minutes'] = Variable<int>(estimatedMinutes);
    }
    map['i18n_json'] = Variable<String>(i18nJson);
    map['resource_links_json'] = Variable<String>(resourceLinksJson);
    return map;
  }

  LessonsCompanion toCompanion(bool nullToAbsent) {
    return LessonsCompanion(
      id: Value(id),
      moduleId: Value(moduleId),
      position: Value(position),
      sourceLang: sourceLang == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceLang),
      unitJson: unitJson == null && nullToAbsent
          ? const Value.absent()
          : Value(unitJson),
      estimatedMinutes: estimatedMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedMinutes),
      i18nJson: Value(i18nJson),
      resourceLinksJson: Value(resourceLinksJson),
    );
  }

  factory LessonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonRow(
      id: serializer.fromJson<int>(json['id']),
      moduleId: serializer.fromJson<int>(json['moduleId']),
      position: serializer.fromJson<int>(json['position']),
      sourceLang: serializer.fromJson<String?>(json['sourceLang']),
      unitJson: serializer.fromJson<String?>(json['unitJson']),
      estimatedMinutes: serializer.fromJson<int?>(json['estimatedMinutes']),
      i18nJson: serializer.fromJson<String>(json['i18nJson']),
      resourceLinksJson: serializer.fromJson<String>(json['resourceLinksJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'moduleId': serializer.toJson<int>(moduleId),
      'position': serializer.toJson<int>(position),
      'sourceLang': serializer.toJson<String?>(sourceLang),
      'unitJson': serializer.toJson<String?>(unitJson),
      'estimatedMinutes': serializer.toJson<int?>(estimatedMinutes),
      'i18nJson': serializer.toJson<String>(i18nJson),
      'resourceLinksJson': serializer.toJson<String>(resourceLinksJson),
    };
  }

  LessonRow copyWith({
    int? id,
    int? moduleId,
    int? position,
    Value<String?> sourceLang = const Value.absent(),
    Value<String?> unitJson = const Value.absent(),
    Value<int?> estimatedMinutes = const Value.absent(),
    String? i18nJson,
    String? resourceLinksJson,
  }) => LessonRow(
    id: id ?? this.id,
    moduleId: moduleId ?? this.moduleId,
    position: position ?? this.position,
    sourceLang: sourceLang.present ? sourceLang.value : this.sourceLang,
    unitJson: unitJson.present ? unitJson.value : this.unitJson,
    estimatedMinutes: estimatedMinutes.present
        ? estimatedMinutes.value
        : this.estimatedMinutes,
    i18nJson: i18nJson ?? this.i18nJson,
    resourceLinksJson: resourceLinksJson ?? this.resourceLinksJson,
  );
  LessonRow copyWithCompanion(LessonsCompanion data) {
    return LessonRow(
      id: data.id.present ? data.id.value : this.id,
      moduleId: data.moduleId.present ? data.moduleId.value : this.moduleId,
      position: data.position.present ? data.position.value : this.position,
      sourceLang: data.sourceLang.present
          ? data.sourceLang.value
          : this.sourceLang,
      unitJson: data.unitJson.present ? data.unitJson.value : this.unitJson,
      estimatedMinutes: data.estimatedMinutes.present
          ? data.estimatedMinutes.value
          : this.estimatedMinutes,
      i18nJson: data.i18nJson.present ? data.i18nJson.value : this.i18nJson,
      resourceLinksJson: data.resourceLinksJson.present
          ? data.resourceLinksJson.value
          : this.resourceLinksJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonRow(')
          ..write('id: $id, ')
          ..write('moduleId: $moduleId, ')
          ..write('position: $position, ')
          ..write('sourceLang: $sourceLang, ')
          ..write('unitJson: $unitJson, ')
          ..write('estimatedMinutes: $estimatedMinutes, ')
          ..write('i18nJson: $i18nJson, ')
          ..write('resourceLinksJson: $resourceLinksJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    moduleId,
    position,
    sourceLang,
    unitJson,
    estimatedMinutes,
    i18nJson,
    resourceLinksJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonRow &&
          other.id == this.id &&
          other.moduleId == this.moduleId &&
          other.position == this.position &&
          other.sourceLang == this.sourceLang &&
          other.unitJson == this.unitJson &&
          other.estimatedMinutes == this.estimatedMinutes &&
          other.i18nJson == this.i18nJson &&
          other.resourceLinksJson == this.resourceLinksJson);
}

class LessonsCompanion extends UpdateCompanion<LessonRow> {
  final Value<int> id;
  final Value<int> moduleId;
  final Value<int> position;
  final Value<String?> sourceLang;
  final Value<String?> unitJson;
  final Value<int?> estimatedMinutes;
  final Value<String> i18nJson;
  final Value<String> resourceLinksJson;
  const LessonsCompanion({
    this.id = const Value.absent(),
    this.moduleId = const Value.absent(),
    this.position = const Value.absent(),
    this.sourceLang = const Value.absent(),
    this.unitJson = const Value.absent(),
    this.estimatedMinutes = const Value.absent(),
    this.i18nJson = const Value.absent(),
    this.resourceLinksJson = const Value.absent(),
  });
  LessonsCompanion.insert({
    this.id = const Value.absent(),
    required int moduleId,
    this.position = const Value.absent(),
    this.sourceLang = const Value.absent(),
    this.unitJson = const Value.absent(),
    this.estimatedMinutes = const Value.absent(),
    required String i18nJson,
    this.resourceLinksJson = const Value.absent(),
  }) : moduleId = Value(moduleId),
       i18nJson = Value(i18nJson);
  static Insertable<LessonRow> custom({
    Expression<int>? id,
    Expression<int>? moduleId,
    Expression<int>? position,
    Expression<String>? sourceLang,
    Expression<String>? unitJson,
    Expression<int>? estimatedMinutes,
    Expression<String>? i18nJson,
    Expression<String>? resourceLinksJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (moduleId != null) 'module_id': moduleId,
      if (position != null) 'position': position,
      if (sourceLang != null) 'source_lang': sourceLang,
      if (unitJson != null) 'unit_json': unitJson,
      if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      if (i18nJson != null) 'i18n_json': i18nJson,
      if (resourceLinksJson != null) 'resource_links_json': resourceLinksJson,
    });
  }

  LessonsCompanion copyWith({
    Value<int>? id,
    Value<int>? moduleId,
    Value<int>? position,
    Value<String?>? sourceLang,
    Value<String?>? unitJson,
    Value<int?>? estimatedMinutes,
    Value<String>? i18nJson,
    Value<String>? resourceLinksJson,
  }) {
    return LessonsCompanion(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      position: position ?? this.position,
      sourceLang: sourceLang ?? this.sourceLang,
      unitJson: unitJson ?? this.unitJson,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      i18nJson: i18nJson ?? this.i18nJson,
      resourceLinksJson: resourceLinksJson ?? this.resourceLinksJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (moduleId.present) {
      map['module_id'] = Variable<int>(moduleId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (sourceLang.present) {
      map['source_lang'] = Variable<String>(sourceLang.value);
    }
    if (unitJson.present) {
      map['unit_json'] = Variable<String>(unitJson.value);
    }
    if (estimatedMinutes.present) {
      map['estimated_minutes'] = Variable<int>(estimatedMinutes.value);
    }
    if (i18nJson.present) {
      map['i18n_json'] = Variable<String>(i18nJson.value);
    }
    if (resourceLinksJson.present) {
      map['resource_links_json'] = Variable<String>(resourceLinksJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonsCompanion(')
          ..write('id: $id, ')
          ..write('moduleId: $moduleId, ')
          ..write('position: $position, ')
          ..write('sourceLang: $sourceLang, ')
          ..write('unitJson: $unitJson, ')
          ..write('estimatedMinutes: $estimatedMinutes, ')
          ..write('i18nJson: $i18nJson, ')
          ..write('resourceLinksJson: $resourceLinksJson')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moduleIdMeta = const VerificationMeta(
    'moduleId',
  );
  @override
  late final GeneratedColumn<int> moduleId = GeneratedColumn<int>(
    'module_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _i18nJsonMeta = const VerificationMeta(
    'i18nJson',
  );
  @override
  late final GeneratedColumn<String> i18nJson = GeneratedColumn<String>(
    'i18n_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonId,
    moduleId,
    position,
    i18nJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('module_id')) {
      context.handle(
        _moduleIdMeta,
        moduleId.isAcceptableOrUnknown(data['module_id']!, _moduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('i18n_json')) {
      context.handle(
        _i18nJsonMeta,
        i18nJson.isAcceptableOrUnknown(data['i18n_json']!, _i18nJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_i18nJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      )!,
      moduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}module_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      i18nJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}i18n_json'],
      )!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final int id;
  final int lessonId;
  final int moduleId;
  final int position;
  final String i18nJson;
  const CardRow({
    required this.id,
    required this.lessonId,
    required this.moduleId,
    required this.position,
    required this.i18nJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lesson_id'] = Variable<int>(lessonId);
    map['module_id'] = Variable<int>(moduleId);
    map['position'] = Variable<int>(position);
    map['i18n_json'] = Variable<String>(i18nJson);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      lessonId: Value(lessonId),
      moduleId: Value(moduleId),
      position: Value(position),
      i18nJson: Value(i18nJson),
    );
  }

  factory CardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      id: serializer.fromJson<int>(json['id']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      moduleId: serializer.fromJson<int>(json['moduleId']),
      position: serializer.fromJson<int>(json['position']),
      i18nJson: serializer.fromJson<String>(json['i18nJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lessonId': serializer.toJson<int>(lessonId),
      'moduleId': serializer.toJson<int>(moduleId),
      'position': serializer.toJson<int>(position),
      'i18nJson': serializer.toJson<String>(i18nJson),
    };
  }

  CardRow copyWith({
    int? id,
    int? lessonId,
    int? moduleId,
    int? position,
    String? i18nJson,
  }) => CardRow(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    moduleId: moduleId ?? this.moduleId,
    position: position ?? this.position,
    i18nJson: i18nJson ?? this.i18nJson,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      id: data.id.present ? data.id.value : this.id,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      moduleId: data.moduleId.present ? data.moduleId.value : this.moduleId,
      position: data.position.present ? data.position.value : this.position,
      i18nJson: data.i18nJson.present ? data.i18nJson.value : this.i18nJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('moduleId: $moduleId, ')
          ..write('position: $position, ')
          ..write('i18nJson: $i18nJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lessonId, moduleId, position, i18nJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.id == this.id &&
          other.lessonId == this.lessonId &&
          other.moduleId == this.moduleId &&
          other.position == this.position &&
          other.i18nJson == this.i18nJson);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<int> id;
  final Value<int> lessonId;
  final Value<int> moduleId;
  final Value<int> position;
  final Value<String> i18nJson;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.moduleId = const Value.absent(),
    this.position = const Value.absent(),
    this.i18nJson = const Value.absent(),
  });
  CardsCompanion.insert({
    this.id = const Value.absent(),
    required int lessonId,
    required int moduleId,
    this.position = const Value.absent(),
    required String i18nJson,
  }) : lessonId = Value(lessonId),
       moduleId = Value(moduleId),
       i18nJson = Value(i18nJson);
  static Insertable<CardRow> custom({
    Expression<int>? id,
    Expression<int>? lessonId,
    Expression<int>? moduleId,
    Expression<int>? position,
    Expression<String>? i18nJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonId != null) 'lesson_id': lessonId,
      if (moduleId != null) 'module_id': moduleId,
      if (position != null) 'position': position,
      if (i18nJson != null) 'i18n_json': i18nJson,
    });
  }

  CardsCompanion copyWith({
    Value<int>? id,
    Value<int>? lessonId,
    Value<int>? moduleId,
    Value<int>? position,
    Value<String>? i18nJson,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      moduleId: moduleId ?? this.moduleId,
      position: position ?? this.position,
      i18nJson: i18nJson ?? this.i18nJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (moduleId.present) {
      map['module_id'] = Variable<int>(moduleId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (i18nJson.present) {
      map['i18n_json'] = Variable<String>(i18nJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('moduleId: $moduleId, ')
          ..write('position: $position, ')
          ..write('i18nJson: $i18nJson')
          ..write(')'))
        .toString();
  }
}

class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, QuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moduleIdMeta = const VerificationMeta(
    'moduleId',
  );
  @override
  late final GeneratedColumn<int> moduleId = GeneratedColumn<int>(
    'module_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctIndexMeta = const VerificationMeta(
    'correctIndex',
  );
  @override
  late final GeneratedColumn<int> correctIndex = GeneratedColumn<int>(
    'correct_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _i18nJsonMeta = const VerificationMeta(
    'i18nJson',
  );
  @override
  late final GeneratedColumn<String> i18nJson = GeneratedColumn<String>(
    'i18n_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonId,
    moduleId,
    kind,
    correctIndex,
    position,
    i18nJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('module_id')) {
      context.handle(
        _moduleIdMeta,
        moduleId.isAcceptableOrUnknown(data['module_id']!, _moduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('correct_index')) {
      context.handle(
        _correctIndexMeta,
        correctIndex.isAcceptableOrUnknown(
          data['correct_index']!,
          _correctIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctIndexMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('i18n_json')) {
      context.handle(
        _i18nJsonMeta,
        i18nJson.isAcceptableOrUnknown(data['i18n_json']!, _i18nJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_i18nJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      )!,
      moduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}module_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      correctIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_index'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      i18nJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}i18n_json'],
      )!,
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }
}

class QuestionRow extends DataClass implements Insertable<QuestionRow> {
  final int id;
  final int lessonId;
  final int moduleId;
  final String kind;
  final int correctIndex;
  final int position;
  final String i18nJson;
  const QuestionRow({
    required this.id,
    required this.lessonId,
    required this.moduleId,
    required this.kind,
    required this.correctIndex,
    required this.position,
    required this.i18nJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lesson_id'] = Variable<int>(lessonId);
    map['module_id'] = Variable<int>(moduleId);
    map['kind'] = Variable<String>(kind);
    map['correct_index'] = Variable<int>(correctIndex);
    map['position'] = Variable<int>(position);
    map['i18n_json'] = Variable<String>(i18nJson);
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      lessonId: Value(lessonId),
      moduleId: Value(moduleId),
      kind: Value(kind),
      correctIndex: Value(correctIndex),
      position: Value(position),
      i18nJson: Value(i18nJson),
    );
  }

  factory QuestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestionRow(
      id: serializer.fromJson<int>(json['id']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      moduleId: serializer.fromJson<int>(json['moduleId']),
      kind: serializer.fromJson<String>(json['kind']),
      correctIndex: serializer.fromJson<int>(json['correctIndex']),
      position: serializer.fromJson<int>(json['position']),
      i18nJson: serializer.fromJson<String>(json['i18nJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lessonId': serializer.toJson<int>(lessonId),
      'moduleId': serializer.toJson<int>(moduleId),
      'kind': serializer.toJson<String>(kind),
      'correctIndex': serializer.toJson<int>(correctIndex),
      'position': serializer.toJson<int>(position),
      'i18nJson': serializer.toJson<String>(i18nJson),
    };
  }

  QuestionRow copyWith({
    int? id,
    int? lessonId,
    int? moduleId,
    String? kind,
    int? correctIndex,
    int? position,
    String? i18nJson,
  }) => QuestionRow(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    moduleId: moduleId ?? this.moduleId,
    kind: kind ?? this.kind,
    correctIndex: correctIndex ?? this.correctIndex,
    position: position ?? this.position,
    i18nJson: i18nJson ?? this.i18nJson,
  );
  QuestionRow copyWithCompanion(QuestionsCompanion data) {
    return QuestionRow(
      id: data.id.present ? data.id.value : this.id,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      moduleId: data.moduleId.present ? data.moduleId.value : this.moduleId,
      kind: data.kind.present ? data.kind.value : this.kind,
      correctIndex: data.correctIndex.present
          ? data.correctIndex.value
          : this.correctIndex,
      position: data.position.present ? data.position.value : this.position,
      i18nJson: data.i18nJson.present ? data.i18nJson.value : this.i18nJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestionRow(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('moduleId: $moduleId, ')
          ..write('kind: $kind, ')
          ..write('correctIndex: $correctIndex, ')
          ..write('position: $position, ')
          ..write('i18nJson: $i18nJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lessonId,
    moduleId,
    kind,
    correctIndex,
    position,
    i18nJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionRow &&
          other.id == this.id &&
          other.lessonId == this.lessonId &&
          other.moduleId == this.moduleId &&
          other.kind == this.kind &&
          other.correctIndex == this.correctIndex &&
          other.position == this.position &&
          other.i18nJson == this.i18nJson);
}

class QuestionsCompanion extends UpdateCompanion<QuestionRow> {
  final Value<int> id;
  final Value<int> lessonId;
  final Value<int> moduleId;
  final Value<String> kind;
  final Value<int> correctIndex;
  final Value<int> position;
  final Value<String> i18nJson;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.moduleId = const Value.absent(),
    this.kind = const Value.absent(),
    this.correctIndex = const Value.absent(),
    this.position = const Value.absent(),
    this.i18nJson = const Value.absent(),
  });
  QuestionsCompanion.insert({
    this.id = const Value.absent(),
    required int lessonId,
    required int moduleId,
    required String kind,
    required int correctIndex,
    this.position = const Value.absent(),
    required String i18nJson,
  }) : lessonId = Value(lessonId),
       moduleId = Value(moduleId),
       kind = Value(kind),
       correctIndex = Value(correctIndex),
       i18nJson = Value(i18nJson);
  static Insertable<QuestionRow> custom({
    Expression<int>? id,
    Expression<int>? lessonId,
    Expression<int>? moduleId,
    Expression<String>? kind,
    Expression<int>? correctIndex,
    Expression<int>? position,
    Expression<String>? i18nJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonId != null) 'lesson_id': lessonId,
      if (moduleId != null) 'module_id': moduleId,
      if (kind != null) 'kind': kind,
      if (correctIndex != null) 'correct_index': correctIndex,
      if (position != null) 'position': position,
      if (i18nJson != null) 'i18n_json': i18nJson,
    });
  }

  QuestionsCompanion copyWith({
    Value<int>? id,
    Value<int>? lessonId,
    Value<int>? moduleId,
    Value<String>? kind,
    Value<int>? correctIndex,
    Value<int>? position,
    Value<String>? i18nJson,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      moduleId: moduleId ?? this.moduleId,
      kind: kind ?? this.kind,
      correctIndex: correctIndex ?? this.correctIndex,
      position: position ?? this.position,
      i18nJson: i18nJson ?? this.i18nJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (moduleId.present) {
      map['module_id'] = Variable<int>(moduleId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (correctIndex.present) {
      map['correct_index'] = Variable<int>(correctIndex.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (i18nJson.present) {
      map['i18n_json'] = Variable<String>(i18nJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('moduleId: $moduleId, ')
          ..write('kind: $kind, ')
          ..write('correctIndex: $correctIndex, ')
          ..write('position: $position, ')
          ..write('i18nJson: $i18nJson')
          ..write(')'))
        .toString();
  }
}

class $ResourcesTable extends Resources
    with TableInfo<$ResourcesTable, ResourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _moduleIdMeta = const VerificationMeta(
    'moduleId',
  );
  @override
  late final GeneratedColumn<int> moduleId = GeneratedColumn<int>(
    'module_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileUrlsJsonMeta = const VerificationMeta(
    'fileUrlsJson',
  );
  @override
  late final GeneratedColumn<String> fileUrlsJson = GeneratedColumn<String>(
    'file_urls_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _trustLabelMeta = const VerificationMeta(
    'trustLabel',
  );
  @override
  late final GeneratedColumn<String> trustLabel = GeneratedColumn<String>(
    'trust_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    moduleId,
    type,
    format,
    title,
    fileUrlsJson,
    trustLabel,
    sizeBytes,
    origin,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resources';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('module_id')) {
      context.handle(
        _moduleIdMeta,
        moduleId.isAcceptableOrUnknown(data['module_id']!, _moduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('file_urls_json')) {
      context.handle(
        _fileUrlsJsonMeta,
        fileUrlsJson.isAcceptableOrUnknown(
          data['file_urls_json']!,
          _fileUrlsJsonMeta,
        ),
      );
    }
    if (data.containsKey('trust_label')) {
      context.handle(
        _trustLabelMeta,
        trustLabel.isAcceptableOrUnknown(data['trust_label']!, _trustLabelMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ResourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      moduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}module_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      fileUrlsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_urls_json'],
      )!,
      trustLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trust_label'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $ResourcesTable createAlias(String alias) {
    return $ResourcesTable(attachedDatabase, alias);
  }
}

class ResourceRow extends DataClass implements Insertable<ResourceRow> {
  final int id;
  final int moduleId;
  final String type;
  final String? format;
  final String title;
  final String fileUrlsJson;
  final String? trustLabel;
  final int? sizeBytes;
  final String? origin;
  final DateTime? createdAt;
  const ResourceRow({
    required this.id,
    required this.moduleId,
    required this.type,
    this.format,
    required this.title,
    required this.fileUrlsJson,
    this.trustLabel,
    this.sizeBytes,
    this.origin,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['module_id'] = Variable<int>(moduleId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    map['title'] = Variable<String>(title);
    map['file_urls_json'] = Variable<String>(fileUrlsJson);
    if (!nullToAbsent || trustLabel != null) {
      map['trust_label'] = Variable<String>(trustLabel);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  ResourcesCompanion toCompanion(bool nullToAbsent) {
    return ResourcesCompanion(
      id: Value(id),
      moduleId: Value(moduleId),
      type: Value(type),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      title: Value(title),
      fileUrlsJson: Value(fileUrlsJson),
      trustLabel: trustLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(trustLabel),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory ResourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResourceRow(
      id: serializer.fromJson<int>(json['id']),
      moduleId: serializer.fromJson<int>(json['moduleId']),
      type: serializer.fromJson<String>(json['type']),
      format: serializer.fromJson<String?>(json['format']),
      title: serializer.fromJson<String>(json['title']),
      fileUrlsJson: serializer.fromJson<String>(json['fileUrlsJson']),
      trustLabel: serializer.fromJson<String?>(json['trustLabel']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      origin: serializer.fromJson<String?>(json['origin']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'moduleId': serializer.toJson<int>(moduleId),
      'type': serializer.toJson<String>(type),
      'format': serializer.toJson<String?>(format),
      'title': serializer.toJson<String>(title),
      'fileUrlsJson': serializer.toJson<String>(fileUrlsJson),
      'trustLabel': serializer.toJson<String?>(trustLabel),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'origin': serializer.toJson<String?>(origin),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  ResourceRow copyWith({
    int? id,
    int? moduleId,
    String? type,
    Value<String?> format = const Value.absent(),
    String? title,
    String? fileUrlsJson,
    Value<String?> trustLabel = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
  }) => ResourceRow(
    id: id ?? this.id,
    moduleId: moduleId ?? this.moduleId,
    type: type ?? this.type,
    format: format.present ? format.value : this.format,
    title: title ?? this.title,
    fileUrlsJson: fileUrlsJson ?? this.fileUrlsJson,
    trustLabel: trustLabel.present ? trustLabel.value : this.trustLabel,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    origin: origin.present ? origin.value : this.origin,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  ResourceRow copyWithCompanion(ResourcesCompanion data) {
    return ResourceRow(
      id: data.id.present ? data.id.value : this.id,
      moduleId: data.moduleId.present ? data.moduleId.value : this.moduleId,
      type: data.type.present ? data.type.value : this.type,
      format: data.format.present ? data.format.value : this.format,
      title: data.title.present ? data.title.value : this.title,
      fileUrlsJson: data.fileUrlsJson.present
          ? data.fileUrlsJson.value
          : this.fileUrlsJson,
      trustLabel: data.trustLabel.present
          ? data.trustLabel.value
          : this.trustLabel,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      origin: data.origin.present ? data.origin.value : this.origin,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceRow(')
          ..write('id: $id, ')
          ..write('moduleId: $moduleId, ')
          ..write('type: $type, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('fileUrlsJson: $fileUrlsJson, ')
          ..write('trustLabel: $trustLabel, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    moduleId,
    type,
    format,
    title,
    fileUrlsJson,
    trustLabel,
    sizeBytes,
    origin,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceRow &&
          other.id == this.id &&
          other.moduleId == this.moduleId &&
          other.type == this.type &&
          other.format == this.format &&
          other.title == this.title &&
          other.fileUrlsJson == this.fileUrlsJson &&
          other.trustLabel == this.trustLabel &&
          other.sizeBytes == this.sizeBytes &&
          other.origin == this.origin &&
          other.createdAt == this.createdAt);
}

class ResourcesCompanion extends UpdateCompanion<ResourceRow> {
  final Value<int> id;
  final Value<int> moduleId;
  final Value<String> type;
  final Value<String?> format;
  final Value<String> title;
  final Value<String> fileUrlsJson;
  final Value<String?> trustLabel;
  final Value<int?> sizeBytes;
  final Value<String?> origin;
  final Value<DateTime?> createdAt;
  const ResourcesCompanion({
    this.id = const Value.absent(),
    this.moduleId = const Value.absent(),
    this.type = const Value.absent(),
    this.format = const Value.absent(),
    this.title = const Value.absent(),
    this.fileUrlsJson = const Value.absent(),
    this.trustLabel = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.origin = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ResourcesCompanion.insert({
    this.id = const Value.absent(),
    required int moduleId,
    required String type,
    this.format = const Value.absent(),
    required String title,
    this.fileUrlsJson = const Value.absent(),
    this.trustLabel = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.origin = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : moduleId = Value(moduleId),
       type = Value(type),
       title = Value(title);
  static Insertable<ResourceRow> custom({
    Expression<int>? id,
    Expression<int>? moduleId,
    Expression<String>? type,
    Expression<String>? format,
    Expression<String>? title,
    Expression<String>? fileUrlsJson,
    Expression<String>? trustLabel,
    Expression<int>? sizeBytes,
    Expression<String>? origin,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (moduleId != null) 'module_id': moduleId,
      if (type != null) 'type': type,
      if (format != null) 'format': format,
      if (title != null) 'title': title,
      if (fileUrlsJson != null) 'file_urls_json': fileUrlsJson,
      if (trustLabel != null) 'trust_label': trustLabel,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (origin != null) 'origin': origin,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ResourcesCompanion copyWith({
    Value<int>? id,
    Value<int>? moduleId,
    Value<String>? type,
    Value<String?>? format,
    Value<String>? title,
    Value<String>? fileUrlsJson,
    Value<String?>? trustLabel,
    Value<int?>? sizeBytes,
    Value<String?>? origin,
    Value<DateTime?>? createdAt,
  }) {
    return ResourcesCompanion(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      type: type ?? this.type,
      format: format ?? this.format,
      title: title ?? this.title,
      fileUrlsJson: fileUrlsJson ?? this.fileUrlsJson,
      trustLabel: trustLabel ?? this.trustLabel,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      origin: origin ?? this.origin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (moduleId.present) {
      map['module_id'] = Variable<int>(moduleId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (fileUrlsJson.present) {
      map['file_urls_json'] = Variable<String>(fileUrlsJson.value);
    }
    if (trustLabel.present) {
      map['trust_label'] = Variable<String>(trustLabel.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourcesCompanion(')
          ..write('id: $id, ')
          ..write('moduleId: $moduleId, ')
          ..write('type: $type, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('fileUrlsJson: $fileUrlsJson, ')
          ..write('trustLabel: $trustLabel, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GlossaryEntriesTable extends GlossaryEntries
    with TableInfo<$GlossaryEntriesTable, GlossaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GlossaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _moduleIdMeta = const VerificationMeta(
    'moduleId',
  );
  @override
  late final GeneratedColumn<int> moduleId = GeneratedColumn<int>(
    'module_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frMeta = const VerificationMeta('fr');
  @override
  late final GeneratedColumn<String> fr = GeneratedColumn<String>(
    'fr',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _arMeta = const VerificationMeta('ar');
  @override
  late final GeneratedColumn<String> ar = GeneratedColumn<String>(
    'ar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enMeta = const VerificationMeta('en');
  @override
  late final GeneratedColumn<String> en = GeneratedColumn<String>(
    'en',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionJsonMeta = const VerificationMeta(
    'definitionJson',
  );
  @override
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
    'definition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    moduleId,
    fr,
    ar,
    en,
    definitionJson,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'glossary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<GlossaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('module_id')) {
      context.handle(
        _moduleIdMeta,
        moduleId.isAcceptableOrUnknown(data['module_id']!, _moduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleIdMeta);
    }
    if (data.containsKey('fr')) {
      context.handle(_frMeta, fr.isAcceptableOrUnknown(data['fr']!, _frMeta));
    }
    if (data.containsKey('ar')) {
      context.handle(_arMeta, ar.isAcceptableOrUnknown(data['ar']!, _arMeta));
    }
    if (data.containsKey('en')) {
      context.handle(_enMeta, en.isAcceptableOrUnknown(data['en']!, _enMeta));
    }
    if (data.containsKey('definition_json')) {
      context.handle(
        _definitionJsonMeta,
        definitionJson.isAcceptableOrUnknown(
          data['definition_json']!,
          _definitionJsonMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GlossaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GlossaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      moduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}module_id'],
      )!,
      fr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fr'],
      ),
      ar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ar'],
      ),
      en: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}en'],
      ),
      definitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_json'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $GlossaryEntriesTable createAlias(String alias) {
    return $GlossaryEntriesTable(attachedDatabase, alias);
  }
}

class GlossaryRow extends DataClass implements Insertable<GlossaryRow> {
  final int id;
  final int moduleId;
  final String? fr;
  final String? ar;
  final String? en;
  final String definitionJson;
  final String? note;
  const GlossaryRow({
    required this.id,
    required this.moduleId,
    this.fr,
    this.ar,
    this.en,
    required this.definitionJson,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['module_id'] = Variable<int>(moduleId);
    if (!nullToAbsent || fr != null) {
      map['fr'] = Variable<String>(fr);
    }
    if (!nullToAbsent || ar != null) {
      map['ar'] = Variable<String>(ar);
    }
    if (!nullToAbsent || en != null) {
      map['en'] = Variable<String>(en);
    }
    map['definition_json'] = Variable<String>(definitionJson);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  GlossaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return GlossaryEntriesCompanion(
      id: Value(id),
      moduleId: Value(moduleId),
      fr: fr == null && nullToAbsent ? const Value.absent() : Value(fr),
      ar: ar == null && nullToAbsent ? const Value.absent() : Value(ar),
      en: en == null && nullToAbsent ? const Value.absent() : Value(en),
      definitionJson: Value(definitionJson),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory GlossaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GlossaryRow(
      id: serializer.fromJson<int>(json['id']),
      moduleId: serializer.fromJson<int>(json['moduleId']),
      fr: serializer.fromJson<String?>(json['fr']),
      ar: serializer.fromJson<String?>(json['ar']),
      en: serializer.fromJson<String?>(json['en']),
      definitionJson: serializer.fromJson<String>(json['definitionJson']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'moduleId': serializer.toJson<int>(moduleId),
      'fr': serializer.toJson<String?>(fr),
      'ar': serializer.toJson<String?>(ar),
      'en': serializer.toJson<String?>(en),
      'definitionJson': serializer.toJson<String>(definitionJson),
      'note': serializer.toJson<String?>(note),
    };
  }

  GlossaryRow copyWith({
    int? id,
    int? moduleId,
    Value<String?> fr = const Value.absent(),
    Value<String?> ar = const Value.absent(),
    Value<String?> en = const Value.absent(),
    String? definitionJson,
    Value<String?> note = const Value.absent(),
  }) => GlossaryRow(
    id: id ?? this.id,
    moduleId: moduleId ?? this.moduleId,
    fr: fr.present ? fr.value : this.fr,
    ar: ar.present ? ar.value : this.ar,
    en: en.present ? en.value : this.en,
    definitionJson: definitionJson ?? this.definitionJson,
    note: note.present ? note.value : this.note,
  );
  GlossaryRow copyWithCompanion(GlossaryEntriesCompanion data) {
    return GlossaryRow(
      id: data.id.present ? data.id.value : this.id,
      moduleId: data.moduleId.present ? data.moduleId.value : this.moduleId,
      fr: data.fr.present ? data.fr.value : this.fr,
      ar: data.ar.present ? data.ar.value : this.ar,
      en: data.en.present ? data.en.value : this.en,
      definitionJson: data.definitionJson.present
          ? data.definitionJson.value
          : this.definitionJson,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GlossaryRow(')
          ..write('id: $id, ')
          ..write('moduleId: $moduleId, ')
          ..write('fr: $fr, ')
          ..write('ar: $ar, ')
          ..write('en: $en, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, moduleId, fr, ar, en, definitionJson, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlossaryRow &&
          other.id == this.id &&
          other.moduleId == this.moduleId &&
          other.fr == this.fr &&
          other.ar == this.ar &&
          other.en == this.en &&
          other.definitionJson == this.definitionJson &&
          other.note == this.note);
}

class GlossaryEntriesCompanion extends UpdateCompanion<GlossaryRow> {
  final Value<int> id;
  final Value<int> moduleId;
  final Value<String?> fr;
  final Value<String?> ar;
  final Value<String?> en;
  final Value<String> definitionJson;
  final Value<String?> note;
  const GlossaryEntriesCompanion({
    this.id = const Value.absent(),
    this.moduleId = const Value.absent(),
    this.fr = const Value.absent(),
    this.ar = const Value.absent(),
    this.en = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.note = const Value.absent(),
  });
  GlossaryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int moduleId,
    this.fr = const Value.absent(),
    this.ar = const Value.absent(),
    this.en = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.note = const Value.absent(),
  }) : moduleId = Value(moduleId);
  static Insertable<GlossaryRow> custom({
    Expression<int>? id,
    Expression<int>? moduleId,
    Expression<String>? fr,
    Expression<String>? ar,
    Expression<String>? en,
    Expression<String>? definitionJson,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (moduleId != null) 'module_id': moduleId,
      if (fr != null) 'fr': fr,
      if (ar != null) 'ar': ar,
      if (en != null) 'en': en,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (note != null) 'note': note,
    });
  }

  GlossaryEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? moduleId,
    Value<String?>? fr,
    Value<String?>? ar,
    Value<String?>? en,
    Value<String>? definitionJson,
    Value<String?>? note,
  }) {
    return GlossaryEntriesCompanion(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      fr: fr ?? this.fr,
      ar: ar ?? this.ar,
      en: en ?? this.en,
      definitionJson: definitionJson ?? this.definitionJson,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (moduleId.present) {
      map['module_id'] = Variable<int>(moduleId.value);
    }
    if (fr.present) {
      map['fr'] = Variable<String>(fr.value);
    }
    if (ar.present) {
      map['ar'] = Variable<String>(ar.value);
    }
    if (en.present) {
      map['en'] = Variable<String>(en.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GlossaryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('moduleId: $moduleId, ')
          ..write('fr: $fr, ')
          ..write('ar: $ar, ')
          ..write('en: $en, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $CardProgressTable extends CardProgress
    with TableInfo<$CardProgressTable, CardProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boxMeta = const VerificationMeta('box');
  @override
  late final GeneratedColumn<int> box = GeneratedColumn<int>(
    'box',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt =
      GeneratedColumn<DateTime>(
        'last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _likedMeta = const VerificationMeta('liked');
  @override
  late final GeneratedColumn<bool> liked = GeneratedColumn<bool>(
    'liked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("liked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _savedMeta = const VerificationMeta('saved');
  @override
  late final GeneratedColumn<bool> saved = GeneratedColumn<bool>(
    'saved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("saved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    cardId,
    box,
    dueAt,
    lastReviewedAt,
    liked,
    saved,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    }
    if (data.containsKey('box')) {
      context.handle(
        _boxMeta,
        box.isAcceptableOrUnknown(data['box']!, _boxMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    if (data.containsKey('liked')) {
      context.handle(
        _likedMeta,
        liked.isAcceptableOrUnknown(data['liked']!, _likedMeta),
      );
    }
    if (data.containsKey('saved')) {
      context.handle(
        _savedMeta,
        saved.isAcceptableOrUnknown(data['saved']!, _savedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  CardProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardProgressRow(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      box: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
      liked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}liked'],
      )!,
      saved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}saved'],
      )!,
    );
  }

  @override
  $CardProgressTable createAlias(String alias) {
    return $CardProgressTable(attachedDatabase, alias);
  }
}

class CardProgressRow extends DataClass implements Insertable<CardProgressRow> {
  final int cardId;
  final int box;
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;
  final bool liked;
  final bool saved;
  const CardProgressRow({
    required this.cardId,
    required this.box,
    this.dueAt,
    this.lastReviewedAt,
    required this.liked,
    required this.saved,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['box'] = Variable<int>(box);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    map['liked'] = Variable<bool>(liked);
    map['saved'] = Variable<bool>(saved);
    return map;
  }

  CardProgressCompanion toCompanion(bool nullToAbsent) {
    return CardProgressCompanion(
      cardId: Value(cardId),
      box: Value(box),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
      liked: Value(liked),
      saved: Value(saved),
    );
  }

  factory CardProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardProgressRow(
      cardId: serializer.fromJson<int>(json['cardId']),
      box: serializer.fromJson<int>(json['box']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
      liked: serializer.fromJson<bool>(json['liked']),
      saved: serializer.fromJson<bool>(json['saved']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'box': serializer.toJson<int>(box),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
      'liked': serializer.toJson<bool>(liked),
      'saved': serializer.toJson<bool>(saved),
    };
  }

  CardProgressRow copyWith({
    int? cardId,
    int? box,
    Value<DateTime?> dueAt = const Value.absent(),
    Value<DateTime?> lastReviewedAt = const Value.absent(),
    bool? liked,
    bool? saved,
  }) => CardProgressRow(
    cardId: cardId ?? this.cardId,
    box: box ?? this.box,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
  );
  CardProgressRow copyWithCompanion(CardProgressCompanion data) {
    return CardProgressRow(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      box: data.box.present ? data.box.value : this.box,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
      liked: data.liked.present ? data.liked.value : this.liked,
      saved: data.saved.present ? data.saved.value : this.saved,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardProgressRow(')
          ..write('cardId: $cardId, ')
          ..write('box: $box, ')
          ..write('dueAt: $dueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('liked: $liked, ')
          ..write('saved: $saved')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(cardId, box, dueAt, lastReviewedAt, liked, saved);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardProgressRow &&
          other.cardId == this.cardId &&
          other.box == this.box &&
          other.dueAt == this.dueAt &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.liked == this.liked &&
          other.saved == this.saved);
}

class CardProgressCompanion extends UpdateCompanion<CardProgressRow> {
  final Value<int> cardId;
  final Value<int> box;
  final Value<DateTime?> dueAt;
  final Value<DateTime?> lastReviewedAt;
  final Value<bool> liked;
  final Value<bool> saved;
  const CardProgressCompanion({
    this.cardId = const Value.absent(),
    this.box = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.liked = const Value.absent(),
    this.saved = const Value.absent(),
  });
  CardProgressCompanion.insert({
    this.cardId = const Value.absent(),
    this.box = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.liked = const Value.absent(),
    this.saved = const Value.absent(),
  });
  static Insertable<CardProgressRow> custom({
    Expression<int>? cardId,
    Expression<int>? box,
    Expression<DateTime>? dueAt,
    Expression<DateTime>? lastReviewedAt,
    Expression<bool>? liked,
    Expression<bool>? saved,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (box != null) 'box': box,
      if (dueAt != null) 'due_at': dueAt,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (liked != null) 'liked': liked,
      if (saved != null) 'saved': saved,
    });
  }

  CardProgressCompanion copyWith({
    Value<int>? cardId,
    Value<int>? box,
    Value<DateTime?>? dueAt,
    Value<DateTime?>? lastReviewedAt,
    Value<bool>? liked,
    Value<bool>? saved,
  }) {
    return CardProgressCompanion(
      cardId: cardId ?? this.cardId,
      box: box ?? this.box,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (box.present) {
      map['box'] = Variable<int>(box.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    if (liked.present) {
      map['liked'] = Variable<bool>(liked.value);
    }
    if (saved.present) {
      map['saved'] = Variable<bool>(saved.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardProgressCompanion(')
          ..write('cardId: $cardId, ')
          ..write('box: $box, ')
          ..write('dueAt: $dueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('liked: $liked, ')
          ..write('saved: $saved')
          ..write(')'))
        .toString();
  }
}

class $LessonProgressTable extends LessonProgress
    with TableInfo<$LessonProgressTable, LessonProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    lessonId,
    completed,
    score,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lessonId};
  @override
  LessonProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonProgressRow(
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $LessonProgressTable createAlias(String alias) {
    return $LessonProgressTable(attachedDatabase, alias);
  }
}

class LessonProgressRow extends DataClass
    implements Insertable<LessonProgressRow> {
  final int lessonId;
  final bool completed;
  final int? score;
  final DateTime? completedAt;
  const LessonProgressRow({
    required this.lessonId,
    required this.completed,
    this.score,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lesson_id'] = Variable<int>(lessonId);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  LessonProgressCompanion toCompanion(bool nullToAbsent) {
    return LessonProgressCompanion(
      lessonId: Value(lessonId),
      completed: Value(completed),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory LessonProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonProgressRow(
      lessonId: serializer.fromJson<int>(json['lessonId']),
      completed: serializer.fromJson<bool>(json['completed']),
      score: serializer.fromJson<int?>(json['score']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lessonId': serializer.toJson<int>(lessonId),
      'completed': serializer.toJson<bool>(completed),
      'score': serializer.toJson<int?>(score),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  LessonProgressRow copyWith({
    int? lessonId,
    bool? completed,
    Value<int?> score = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
  }) => LessonProgressRow(
    lessonId: lessonId ?? this.lessonId,
    completed: completed ?? this.completed,
    score: score.present ? score.value : this.score,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  LessonProgressRow copyWithCompanion(LessonProgressCompanion data) {
    return LessonProgressRow(
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      completed: data.completed.present ? data.completed.value : this.completed,
      score: data.score.present ? data.score.value : this.score,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressRow(')
          ..write('lessonId: $lessonId, ')
          ..write('completed: $completed, ')
          ..write('score: $score, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(lessonId, completed, score, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonProgressRow &&
          other.lessonId == this.lessonId &&
          other.completed == this.completed &&
          other.score == this.score &&
          other.completedAt == this.completedAt);
}

class LessonProgressCompanion extends UpdateCompanion<LessonProgressRow> {
  final Value<int> lessonId;
  final Value<bool> completed;
  final Value<int?> score;
  final Value<DateTime?> completedAt;
  const LessonProgressCompanion({
    this.lessonId = const Value.absent(),
    this.completed = const Value.absent(),
    this.score = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  LessonProgressCompanion.insert({
    this.lessonId = const Value.absent(),
    this.completed = const Value.absent(),
    this.score = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  static Insertable<LessonProgressRow> custom({
    Expression<int>? lessonId,
    Expression<bool>? completed,
    Expression<int>? score,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (lessonId != null) 'lesson_id': lessonId,
      if (completed != null) 'completed': completed,
      if (score != null) 'score': score,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  LessonProgressCompanion copyWith({
    Value<int>? lessonId,
    Value<bool>? completed,
    Value<int?>? score,
    Value<DateTime?>? completedAt,
  }) {
    return LessonProgressCompanion(
      lessonId: lessonId ?? this.lessonId,
      completed: completed ?? this.completed,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressCompanion(')
          ..write('lessonId: $lessonId, ')
          ..write('completed: $completed, ')
          ..write('score: $score, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingPositionsTable extends ReadingPositions
    with TableInfo<$ReadingPositionsTable, ReadingPositionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    lessonId,
    blockId,
    progress,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingPositionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    } else if (isInserting) {
      context.missing(_progressMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lessonId};
  @override
  ReadingPositionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingPositionRow(
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingPositionsTable createAlias(String alias) {
    return $ReadingPositionsTable(attachedDatabase, alias);
  }
}

class ReadingPositionRow extends DataClass
    implements Insertable<ReadingPositionRow> {
  final int lessonId;
  final String blockId;
  final double progress;
  final DateTime updatedAt;
  const ReadingPositionRow({
    required this.lessonId,
    required this.blockId,
    required this.progress,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lesson_id'] = Variable<int>(lessonId);
    map['block_id'] = Variable<String>(blockId);
    map['progress'] = Variable<double>(progress);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingPositionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingPositionsCompanion(
      lessonId: Value(lessonId),
      blockId: Value(blockId),
      progress: Value(progress),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingPositionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingPositionRow(
      lessonId: serializer.fromJson<int>(json['lessonId']),
      blockId: serializer.fromJson<String>(json['blockId']),
      progress: serializer.fromJson<double>(json['progress']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lessonId': serializer.toJson<int>(lessonId),
      'blockId': serializer.toJson<String>(blockId),
      'progress': serializer.toJson<double>(progress),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingPositionRow copyWith({
    int? lessonId,
    String? blockId,
    double? progress,
    DateTime? updatedAt,
  }) => ReadingPositionRow(
    lessonId: lessonId ?? this.lessonId,
    blockId: blockId ?? this.blockId,
    progress: progress ?? this.progress,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingPositionRow copyWithCompanion(ReadingPositionsCompanion data) {
    return ReadingPositionRow(
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      progress: data.progress.present ? data.progress.value : this.progress,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPositionRow(')
          ..write('lessonId: $lessonId, ')
          ..write('blockId: $blockId, ')
          ..write('progress: $progress, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(lessonId, blockId, progress, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingPositionRow &&
          other.lessonId == this.lessonId &&
          other.blockId == this.blockId &&
          other.progress == this.progress &&
          other.updatedAt == this.updatedAt);
}

class ReadingPositionsCompanion extends UpdateCompanion<ReadingPositionRow> {
  final Value<int> lessonId;
  final Value<String> blockId;
  final Value<double> progress;
  final Value<DateTime> updatedAt;
  const ReadingPositionsCompanion({
    this.lessonId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.progress = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReadingPositionsCompanion.insert({
    this.lessonId = const Value.absent(),
    required String blockId,
    required double progress,
    required DateTime updatedAt,
  }) : blockId = Value(blockId),
       progress = Value(progress),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingPositionRow> custom({
    Expression<int>? lessonId,
    Expression<String>? blockId,
    Expression<double>? progress,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (lessonId != null) 'lesson_id': lessonId,
      if (blockId != null) 'block_id': blockId,
      if (progress != null) 'progress': progress,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReadingPositionsCompanion copyWith({
    Value<int>? lessonId,
    Value<String>? blockId,
    Value<double>? progress,
    Value<DateTime>? updatedAt,
  }) {
    return ReadingPositionsCompanion(
      lessonId: lessonId ?? this.lessonId,
      blockId: blockId ?? this.blockId,
      progress: progress ?? this.progress,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPositionsCompanion(')
          ..write('lessonId: $lessonId, ')
          ..write('blockId: $blockId, ')
          ..write('progress: $progress, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $StudyDaysTable extends StudyDays
    with TableInfo<$StudyDaysTable, StudyDayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secondsMeta = const VerificationMeta(
    'seconds',
  );
  @override
  late final GeneratedColumn<int> seconds = GeneratedColumn<int>(
    'seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [day, seconds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyDayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('seconds')) {
      context.handle(
        _secondsMeta,
        seconds.isAcceptableOrUnknown(data['seconds']!, _secondsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  StudyDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyDayRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seconds'],
      )!,
    );
  }

  @override
  $StudyDaysTable createAlias(String alias) {
    return $StudyDaysTable(attachedDatabase, alias);
  }
}

class StudyDayRow extends DataClass implements Insertable<StudyDayRow> {
  final String day;
  final int seconds;
  const StudyDayRow({required this.day, required this.seconds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['seconds'] = Variable<int>(seconds);
    return map;
  }

  StudyDaysCompanion toCompanion(bool nullToAbsent) {
    return StudyDaysCompanion(day: Value(day), seconds: Value(seconds));
  }

  factory StudyDayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyDayRow(
      day: serializer.fromJson<String>(json['day']),
      seconds: serializer.fromJson<int>(json['seconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'seconds': serializer.toJson<int>(seconds),
    };
  }

  StudyDayRow copyWith({String? day, int? seconds}) =>
      StudyDayRow(day: day ?? this.day, seconds: seconds ?? this.seconds);
  StudyDayRow copyWithCompanion(StudyDaysCompanion data) {
    return StudyDayRow(
      day: data.day.present ? data.day.value : this.day,
      seconds: data.seconds.present ? data.seconds.value : this.seconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyDayRow(')
          ..write('day: $day, ')
          ..write('seconds: $seconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, seconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyDayRow &&
          other.day == this.day &&
          other.seconds == this.seconds);
}

class StudyDaysCompanion extends UpdateCompanion<StudyDayRow> {
  final Value<String> day;
  final Value<int> seconds;
  final Value<int> rowid;
  const StudyDaysCompanion({
    this.day = const Value.absent(),
    this.seconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyDaysCompanion.insert({
    required String day,
    this.seconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day);
  static Insertable<StudyDayRow> custom({
    Expression<String>? day,
    Expression<int>? seconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (seconds != null) 'seconds': seconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyDaysCompanion copyWith({
    Value<String>? day,
    Value<int>? seconds,
    Value<int>? rowid,
  }) {
    return StudyDaysCompanion(
      day: day ?? this.day,
      seconds: seconds ?? this.seconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (seconds.present) {
      map['seconds'] = Variable<int>(seconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyDaysCompanion(')
          ..write('day: $day, ')
          ..write('seconds: $seconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replaceKeyMeta = const VerificationMeta(
    'replaceKey',
  );
  @override
  late final GeneratedColumn<String> replaceKey = GeneratedColumn<String>(
    'replace_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    opId,
    seq,
    kind,
    payloadJson,
    replaceKey,
    attempts,
    createdAt,
    nextAttemptAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('replace_key')) {
      context.handle(
        _replaceKeyMeta,
        replaceKey.isAcceptableOrUnknown(data['replace_key']!, _replaceKeyMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      replaceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replace_key'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final String opId;
  final int seq;
  final String kind;
  final String payloadJson;
  final String? replaceKey;
  final int attempts;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final String? lastError;
  const OutboxRow({
    required this.opId,
    required this.seq,
    required this.kind,
    required this.payloadJson,
    this.replaceKey,
    required this.attempts,
    required this.createdAt,
    required this.nextAttemptAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['seq'] = Variable<int>(seq);
    map['kind'] = Variable<String>(kind);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || replaceKey != null) {
      map['replace_key'] = Variable<String>(replaceKey);
    }
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      opId: Value(opId),
      seq: Value(seq),
      kind: Value(kind),
      payloadJson: Value(payloadJson),
      replaceKey: replaceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(replaceKey),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      opId: serializer.fromJson<String>(json['opId']),
      seq: serializer.fromJson<int>(json['seq']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      replaceKey: serializer.fromJson<String?>(json['replaceKey']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'seq': serializer.toJson<int>(seq),
      'kind': serializer.toJson<String>(kind),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'replaceKey': serializer.toJson<String?>(replaceKey),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxRow copyWith({
    String? opId,
    int? seq,
    String? kind,
    String? payloadJson,
    Value<String?> replaceKey = const Value.absent(),
    int? attempts,
    DateTime? createdAt,
    DateTime? nextAttemptAt,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxRow(
    opId: opId ?? this.opId,
    seq: seq ?? this.seq,
    kind: kind ?? this.kind,
    payloadJson: payloadJson ?? this.payloadJson,
    replaceKey: replaceKey.present ? replaceKey.value : this.replaceKey,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      opId: data.opId.present ? data.opId.value : this.opId,
      seq: data.seq.present ? data.seq.value : this.seq,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      replaceKey: data.replaceKey.present
          ? data.replaceKey.value
          : this.replaceKey,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('opId: $opId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('replaceKey: $replaceKey, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    opId,
    seq,
    kind,
    payloadJson,
    replaceKey,
    attempts,
    createdAt,
    nextAttemptAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.opId == this.opId &&
          other.seq == this.seq &&
          other.kind == this.kind &&
          other.payloadJson == this.payloadJson &&
          other.replaceKey == this.replaceKey &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> opId;
  final Value<int> seq;
  final Value<String> kind;
  final Value<String> payloadJson;
  final Value<String?> replaceKey;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  final Value<DateTime> nextAttemptAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const OutboxCompanion({
    this.opId = const Value.absent(),
    this.seq = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.replaceKey = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String opId,
    required int seq,
    required String kind,
    required String payloadJson,
    this.replaceKey = const Value.absent(),
    this.attempts = const Value.absent(),
    required DateTime createdAt,
    required DateTime nextAttemptAt,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : opId = Value(opId),
       seq = Value(seq),
       kind = Value(kind),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       nextAttemptAt = Value(nextAttemptAt);
  static Insertable<OutboxRow> custom({
    Expression<String>? opId,
    Expression<int>? seq,
    Expression<String>? kind,
    Expression<String>? payloadJson,
    Expression<String>? replaceKey,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (seq != null) 'seq': seq,
      if (kind != null) 'kind': kind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (replaceKey != null) 'replace_key': replaceKey,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? opId,
    Value<int>? seq,
    Value<String>? kind,
    Value<String>? payloadJson,
    Value<String?>? replaceKey,
    Value<int>? attempts,
    Value<DateTime>? createdAt,
    Value<DateTime>? nextAttemptAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      opId: opId ?? this.opId,
      seq: seq ?? this.seq,
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
      replaceKey: replaceKey ?? this.replaceKey,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (replaceKey.present) {
      map['replace_key'] = Variable<String>(replaceKey.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('opId: $opId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('replaceKey: $replaceKey, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  KeyValueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValueRow(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValueRow extends DataClass implements Insertable<KeyValueRow> {
  final String name;
  final String value;
  const KeyValueRow({required this.name, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(name: Value(name), value: Value(value));
  }

  factory KeyValueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValueRow(
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValueRow copyWith({String? name, String? value}) =>
      KeyValueRow(name: name ?? this.name, value: value ?? this.value);
  KeyValueRow copyWithCompanion(KeyValuesCompanion data) {
    return KeyValueRow(
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueRow(')
          ..write('name: $name, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValueRow &&
          other.name == this.name &&
          other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValueRow> {
  final Value<String> name;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String name,
    required String value,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       value = Value(value);
  static Insertable<KeyValueRow> custom({
    Expression<String>? name,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? name,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      name: name ?? this.name,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ModulesTable modules = $ModulesTable(this);
  late final $LessonsTable lessons = $LessonsTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  late final $ResourcesTable resources = $ResourcesTable(this);
  late final $GlossaryEntriesTable glossaryEntries = $GlossaryEntriesTable(
    this,
  );
  late final $CardProgressTable cardProgress = $CardProgressTable(this);
  late final $LessonProgressTable lessonProgress = $LessonProgressTable(this);
  late final $ReadingPositionsTable readingPositions = $ReadingPositionsTable(
    this,
  );
  late final $StudyDaysTable studyDays = $StudyDaysTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    modules,
    lessons,
    cards,
    questions,
    resources,
    glossaryEntries,
    cardProgress,
    lessonProgress,
    readingPositions,
    studyDays,
    outbox,
    keyValues,
  ];
}

typedef $$ModulesTableCreateCompanionBuilder = ModulesCompanion Function({
  Value<int> id,
  required String name,
  Value<int?> semester,
  Value<String?> ueCategory,
  Value<String?> academicYear,
  Value<int> serverVersion,
  Value<int> localVersion,
  Value<int> lessonCount,
  Value<int> lessonsDone,
  Value<int> resourceCount,
  Value<String> languages,
  Value<DateTime?> downloadedAt,
});
typedef $$ModulesTableUpdateCompanionBuilder = ModulesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int?> semester,
  Value<String?> ueCategory,
  Value<String?> academicYear,
  Value<int> serverVersion,
  Value<int> localVersion,
  Value<int> lessonCount,
  Value<int> lessonsDone,
  Value<int> resourceCount,
  Value<String> languages,
  Value<DateTime?> downloadedAt,
});

class $$ModulesTableFilterComposer
    extends Composer<_$AppDatabase, $ModulesTable> {
  $$ModulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get semester => $composableBuilder(
    column: $table.semester,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ueCategory => $composableBuilder(
    column: $table.ueCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get academicYear => $composableBuilder(
    column: $table.academicYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonCount => $composableBuilder(
    column: $table.lessonCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonsDone => $composableBuilder(
    column: $table.lessonsDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resourceCount => $composableBuilder(
    column: $table.resourceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languages => $composableBuilder(
    column: $table.languages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModulesTableOrderingComposer
    extends Composer<_$AppDatabase, $ModulesTable> {
  $$ModulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get semester => $composableBuilder(
    column: $table.semester,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ueCategory => $composableBuilder(
    column: $table.ueCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get academicYear => $composableBuilder(
    column: $table.academicYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonCount => $composableBuilder(
    column: $table.lessonCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonsDone => $composableBuilder(
    column: $table.lessonsDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resourceCount => $composableBuilder(
    column: $table.resourceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languages => $composableBuilder(
    column: $table.languages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModulesTable> {
  $$ModulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get semester =>
      $composableBuilder(column: $table.semester, builder: (column) => column);

  GeneratedColumn<String> get ueCategory => $composableBuilder(
    column: $table.ueCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get academicYear => $composableBuilder(
    column: $table.academicYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lessonCount => $composableBuilder(
    column: $table.lessonCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lessonsDone => $composableBuilder(
    column: $table.lessonsDone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resourceCount => $composableBuilder(
    column: $table.resourceCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get languages =>
      $composableBuilder(column: $table.languages, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$ModulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModulesTable,
          ModuleRow,
          $$ModulesTableFilterComposer,
          $$ModulesTableOrderingComposer,
          $$ModulesTableAnnotationComposer,
          $$ModulesTableCreateCompanionBuilder,
          $$ModulesTableUpdateCompanionBuilder,
          (ModuleRow, BaseReferences<_$AppDatabase, $ModulesTable, ModuleRow>),
          ModuleRow,
          PrefetchHooks Function()
        > {
  $$ModulesTableTableManager(_$AppDatabase db, $ModulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> semester = const Value.absent(),
                Value<String?> ueCategory = const Value.absent(),
                Value<String?> academicYear = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> lessonCount = const Value.absent(),
                Value<int> lessonsDone = const Value.absent(),
                Value<int> resourceCount = const Value.absent(),
                Value<String> languages = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
              }) => ModulesCompanion(
                id: id,
                name: name,
                semester: semester,
                ueCategory: ueCategory,
                academicYear: academicYear,
                serverVersion: serverVersion,
                localVersion: localVersion,
                lessonCount: lessonCount,
                lessonsDone: lessonsDone,
                resourceCount: resourceCount,
                languages: languages,
                downloadedAt: downloadedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> semester = const Value.absent(),
                Value<String?> ueCategory = const Value.absent(),
                Value<String?> academicYear = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> lessonCount = const Value.absent(),
                Value<int> lessonsDone = const Value.absent(),
                Value<int> resourceCount = const Value.absent(),
                Value<String> languages = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
              }) => ModulesCompanion.insert(
                id: id,
                name: name,
                semester: semester,
                ueCategory: ueCategory,
                academicYear: academicYear,
                serverVersion: serverVersion,
                localVersion: localVersion,
                lessonCount: lessonCount,
                lessonsDone: lessonsDone,
                resourceCount: resourceCount,
                languages: languages,
                downloadedAt: downloadedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModulesTable, ModuleRow>(table),
                  BaseReferences<_$AppDatabase, $ModulesTable, ModuleRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModulesTable,
      ModuleRow,
      $$ModulesTableFilterComposer,
      $$ModulesTableOrderingComposer,
      $$ModulesTableAnnotationComposer,
      $$ModulesTableCreateCompanionBuilder,
      $$ModulesTableUpdateCompanionBuilder,
      (ModuleRow, BaseReferences<_$AppDatabase, $ModulesTable, ModuleRow>),
      ModuleRow,
      PrefetchHooks Function()
    >;
typedef $$LessonsTableCreateCompanionBuilder = LessonsCompanion Function({
  Value<int> id,
  required int moduleId,
  Value<int> position,
  Value<String?> sourceLang,
  Value<String?> unitJson,
  Value<int?> estimatedMinutes,
  required String i18nJson,
  Value<String> resourceLinksJson,
});
typedef $$LessonsTableUpdateCompanionBuilder = LessonsCompanion Function({
  Value<int> id,
  Value<int> moduleId,
  Value<int> position,
  Value<String?> sourceLang,
  Value<String?> unitJson,
  Value<int?> estimatedMinutes,
  Value<String> i18nJson,
  Value<String> resourceLinksJson,
});

class $$LessonsTableFilterComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLang => $composableBuilder(
    column: $table.sourceLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitJson => $composableBuilder(
    column: $table.unitJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get i18nJson => $composableBuilder(
    column: $table.i18nJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceLinksJson => $composableBuilder(
    column: $table.resourceLinksJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonsTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLang => $composableBuilder(
    column: $table.sourceLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitJson => $composableBuilder(
    column: $table.unitJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get i18nJson => $composableBuilder(
    column: $table.i18nJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceLinksJson => $composableBuilder(
    column: $table.resourceLinksJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get moduleId =>
      $composableBuilder(column: $table.moduleId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get sourceLang => $composableBuilder(
    column: $table.sourceLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitJson =>
      $composableBuilder(column: $table.unitJson, builder: (column) => column);

  GeneratedColumn<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get i18nJson =>
      $composableBuilder(column: $table.i18nJson, builder: (column) => column);

  GeneratedColumn<String> get resourceLinksJson => $composableBuilder(
    column: $table.resourceLinksJson,
    builder: (column) => column,
  );
}

class $$LessonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonsTable,
          LessonRow,
          $$LessonsTableFilterComposer,
          $$LessonsTableOrderingComposer,
          $$LessonsTableAnnotationComposer,
          $$LessonsTableCreateCompanionBuilder,
          $$LessonsTableUpdateCompanionBuilder,
          (LessonRow, BaseReferences<_$AppDatabase, $LessonsTable, LessonRow>),
          LessonRow,
          PrefetchHooks Function()
        > {
  $$LessonsTableTableManager(_$AppDatabase db, $LessonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> moduleId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> sourceLang = const Value.absent(),
                Value<String?> unitJson = const Value.absent(),
                Value<int?> estimatedMinutes = const Value.absent(),
                Value<String> i18nJson = const Value.absent(),
                Value<String> resourceLinksJson = const Value.absent(),
              }) => LessonsCompanion(
                id: id,
                moduleId: moduleId,
                position: position,
                sourceLang: sourceLang,
                unitJson: unitJson,
                estimatedMinutes: estimatedMinutes,
                i18nJson: i18nJson,
                resourceLinksJson: resourceLinksJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int moduleId,
                Value<int> position = const Value.absent(),
                Value<String?> sourceLang = const Value.absent(),
                Value<String?> unitJson = const Value.absent(),
                Value<int?> estimatedMinutes = const Value.absent(),
                required String i18nJson,
                Value<String> resourceLinksJson = const Value.absent(),
              }) => LessonsCompanion.insert(
                id: id,
                moduleId: moduleId,
                position: position,
                sourceLang: sourceLang,
                unitJson: unitJson,
                estimatedMinutes: estimatedMinutes,
                i18nJson: i18nJson,
                resourceLinksJson: resourceLinksJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LessonsTable, LessonRow>(table),
                  BaseReferences<_$AppDatabase, $LessonsTable, LessonRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonsTable,
      LessonRow,
      $$LessonsTableFilterComposer,
      $$LessonsTableOrderingComposer,
      $$LessonsTableAnnotationComposer,
      $$LessonsTableCreateCompanionBuilder,
      $$LessonsTableUpdateCompanionBuilder,
      (LessonRow, BaseReferences<_$AppDatabase, $LessonsTable, LessonRow>),
      LessonRow,
      PrefetchHooks Function()
    >;
typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  Value<int> id,
  required int lessonId,
  required int moduleId,
  Value<int> position,
  required String i18nJson,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<int> id,
  Value<int> lessonId,
  Value<int> moduleId,
  Value<int> position,
  Value<String> i18nJson,
});

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get i18nJson => $composableBuilder(
    column: $table.i18nJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get i18nJson => $composableBuilder(
    column: $table.i18nJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get moduleId =>
      $composableBuilder(column: $table.moduleId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get i18nJson =>
      $composableBuilder(column: $table.i18nJson, builder: (column) => column);
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, BaseReferences<_$AppDatabase, $CardsTable, CardRow>),
          CardRow,
          PrefetchHooks Function()
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<int> moduleId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> i18nJson = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                lessonId: lessonId,
                moduleId: moduleId,
                position: position,
                i18nJson: i18nJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lessonId,
                required int moduleId,
                Value<int> position = const Value.absent(),
                required String i18nJson,
              }) => CardsCompanion.insert(
                id: id,
                lessonId: lessonId,
                moduleId: moduleId,
                position: position,
                i18nJson: i18nJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsTable, CardRow>(table),
                  BaseReferences<_$AppDatabase, $CardsTable, CardRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, BaseReferences<_$AppDatabase, $CardsTable, CardRow>),
      CardRow,
      PrefetchHooks Function()
    >;
typedef $$QuestionsTableCreateCompanionBuilder = QuestionsCompanion Function({
  Value<int> id,
  required int lessonId,
  required int moduleId,
  required String kind,
  required int correctIndex,
  Value<int> position,
  required String i18nJson,
});
typedef $$QuestionsTableUpdateCompanionBuilder = QuestionsCompanion Function({
  Value<int> id,
  Value<int> lessonId,
  Value<int> moduleId,
  Value<String> kind,
  Value<int> correctIndex,
  Value<int> position,
  Value<String> i18nJson,
});

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get i18nJson => $composableBuilder(
    column: $table.i18nJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get i18nJson => $composableBuilder(
    column: $table.i18nJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get moduleId =>
      $composableBuilder(column: $table.moduleId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get i18nJson =>
      $composableBuilder(column: $table.i18nJson, builder: (column) => column);
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          QuestionRow,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (
            QuestionRow,
            BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>,
          ),
          QuestionRow,
          PrefetchHooks Function()
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<int> moduleId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> correctIndex = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> i18nJson = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                lessonId: lessonId,
                moduleId: moduleId,
                kind: kind,
                correctIndex: correctIndex,
                position: position,
                i18nJson: i18nJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lessonId,
                required int moduleId,
                required String kind,
                required int correctIndex,
                Value<int> position = const Value.absent(),
                required String i18nJson,
              }) => QuestionsCompanion.insert(
                id: id,
                lessonId: lessonId,
                moduleId: moduleId,
                kind: kind,
                correctIndex: correctIndex,
                position: position,
                i18nJson: i18nJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestionsTable, QuestionRow>(table),
                  BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      QuestionRow,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (
        QuestionRow,
        BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>,
      ),
      QuestionRow,
      PrefetchHooks Function()
    >;
typedef $$ResourcesTableCreateCompanionBuilder = ResourcesCompanion Function({
  Value<int> id,
  required int moduleId,
  required String type,
  Value<String?> format,
  required String title,
  Value<String> fileUrlsJson,
  Value<String?> trustLabel,
  Value<int?> sizeBytes,
  Value<String?> origin,
  Value<DateTime?> createdAt,
});
typedef $$ResourcesTableUpdateCompanionBuilder = ResourcesCompanion Function({
  Value<int> id,
  Value<int> moduleId,
  Value<String> type,
  Value<String?> format,
  Value<String> title,
  Value<String> fileUrlsJson,
  Value<String?> trustLabel,
  Value<int?> sizeBytes,
  Value<String?> origin,
  Value<DateTime?> createdAt,
});

class $$ResourcesTableFilterComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileUrlsJson => $composableBuilder(
    column: $table.fileUrlsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trustLabel => $composableBuilder(
    column: $table.trustLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileUrlsJson => $composableBuilder(
    column: $table.fileUrlsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trustLabel => $composableBuilder(
    column: $table.trustLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get moduleId =>
      $composableBuilder(column: $table.moduleId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get fileUrlsJson => $composableBuilder(
    column: $table.fileUrlsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trustLabel => $composableBuilder(
    column: $table.trustLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ResourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResourcesTable,
          ResourceRow,
          $$ResourcesTableFilterComposer,
          $$ResourcesTableOrderingComposer,
          $$ResourcesTableAnnotationComposer,
          $$ResourcesTableCreateCompanionBuilder,
          $$ResourcesTableUpdateCompanionBuilder,
          (
            ResourceRow,
            BaseReferences<_$AppDatabase, $ResourcesTable, ResourceRow>,
          ),
          ResourceRow,
          PrefetchHooks Function()
        > {
  $$ResourcesTableTableManager(_$AppDatabase db, $ResourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> moduleId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> fileUrlsJson = const Value.absent(),
                Value<String?> trustLabel = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
              }) => ResourcesCompanion(
                id: id,
                moduleId: moduleId,
                type: type,
                format: format,
                title: title,
                fileUrlsJson: fileUrlsJson,
                trustLabel: trustLabel,
                sizeBytes: sizeBytes,
                origin: origin,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int moduleId,
                required String type,
                Value<String?> format = const Value.absent(),
                required String title,
                Value<String> fileUrlsJson = const Value.absent(),
                Value<String?> trustLabel = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
              }) => ResourcesCompanion.insert(
                id: id,
                moduleId: moduleId,
                type: type,
                format: format,
                title: title,
                fileUrlsJson: fileUrlsJson,
                trustLabel: trustLabel,
                sizeBytes: sizeBytes,
                origin: origin,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResourcesTable, ResourceRow>(table),
                  BaseReferences<_$AppDatabase, $ResourcesTable, ResourceRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResourcesTable,
      ResourceRow,
      $$ResourcesTableFilterComposer,
      $$ResourcesTableOrderingComposer,
      $$ResourcesTableAnnotationComposer,
      $$ResourcesTableCreateCompanionBuilder,
      $$ResourcesTableUpdateCompanionBuilder,
      (
        ResourceRow,
        BaseReferences<_$AppDatabase, $ResourcesTable, ResourceRow>,
      ),
      ResourceRow,
      PrefetchHooks Function()
    >;
typedef $$GlossaryEntriesTableCreateCompanionBuilder =
    GlossaryEntriesCompanion Function({
      Value<int> id,
      required int moduleId,
      Value<String?> fr,
      Value<String?> ar,
      Value<String?> en,
      Value<String> definitionJson,
      Value<String?> note,
    });
typedef $$GlossaryEntriesTableUpdateCompanionBuilder =
    GlossaryEntriesCompanion Function({
      Value<int> id,
      Value<int> moduleId,
      Value<String?> fr,
      Value<String?> ar,
      Value<String?> en,
      Value<String> definitionJson,
      Value<String?> note,
    });

class $$GlossaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GlossaryEntriesTable> {
  $$GlossaryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fr => $composableBuilder(
    column: $table.fr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ar => $composableBuilder(
    column: $table.ar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get en => $composableBuilder(
    column: $table.en,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GlossaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GlossaryEntriesTable> {
  $$GlossaryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moduleId => $composableBuilder(
    column: $table.moduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fr => $composableBuilder(
    column: $table.fr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ar => $composableBuilder(
    column: $table.ar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get en => $composableBuilder(
    column: $table.en,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GlossaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GlossaryEntriesTable> {
  $$GlossaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get moduleId =>
      $composableBuilder(column: $table.moduleId, builder: (column) => column);

  GeneratedColumn<String> get fr =>
      $composableBuilder(column: $table.fr, builder: (column) => column);

  GeneratedColumn<String> get ar =>
      $composableBuilder(column: $table.ar, builder: (column) => column);

  GeneratedColumn<String> get en =>
      $composableBuilder(column: $table.en, builder: (column) => column);

  GeneratedColumn<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$GlossaryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GlossaryEntriesTable,
          GlossaryRow,
          $$GlossaryEntriesTableFilterComposer,
          $$GlossaryEntriesTableOrderingComposer,
          $$GlossaryEntriesTableAnnotationComposer,
          $$GlossaryEntriesTableCreateCompanionBuilder,
          $$GlossaryEntriesTableUpdateCompanionBuilder,
          (
            GlossaryRow,
            BaseReferences<_$AppDatabase, $GlossaryEntriesTable, GlossaryRow>,
          ),
          GlossaryRow,
          PrefetchHooks Function()
        > {
  $$GlossaryEntriesTableTableManager(
    _$AppDatabase db,
    $GlossaryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GlossaryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GlossaryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GlossaryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> moduleId = const Value.absent(),
                Value<String?> fr = const Value.absent(),
                Value<String?> ar = const Value.absent(),
                Value<String?> en = const Value.absent(),
                Value<String> definitionJson = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => GlossaryEntriesCompanion(
                id: id,
                moduleId: moduleId,
                fr: fr,
                ar: ar,
                en: en,
                definitionJson: definitionJson,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int moduleId,
                Value<String?> fr = const Value.absent(),
                Value<String?> ar = const Value.absent(),
                Value<String?> en = const Value.absent(),
                Value<String> definitionJson = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => GlossaryEntriesCompanion.insert(
                id: id,
                moduleId: moduleId,
                fr: fr,
                ar: ar,
                en: en,
                definitionJson: definitionJson,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GlossaryEntriesTable, GlossaryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GlossaryEntriesTable,
                    GlossaryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GlossaryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GlossaryEntriesTable,
      GlossaryRow,
      $$GlossaryEntriesTableFilterComposer,
      $$GlossaryEntriesTableOrderingComposer,
      $$GlossaryEntriesTableAnnotationComposer,
      $$GlossaryEntriesTableCreateCompanionBuilder,
      $$GlossaryEntriesTableUpdateCompanionBuilder,
      (
        GlossaryRow,
        BaseReferences<_$AppDatabase, $GlossaryEntriesTable, GlossaryRow>,
      ),
      GlossaryRow,
      PrefetchHooks Function()
    >;
typedef $$CardProgressTableCreateCompanionBuilder =
    CardProgressCompanion Function({
      Value<int> cardId,
      Value<int> box,
      Value<DateTime?> dueAt,
      Value<DateTime?> lastReviewedAt,
      Value<bool> liked,
      Value<bool> saved,
    });
typedef $$CardProgressTableUpdateCompanionBuilder =
    CardProgressCompanion Function({
      Value<int> cardId,
      Value<int> box,
      Value<DateTime?> dueAt,
      Value<DateTime?> lastReviewedAt,
      Value<bool> liked,
      Value<bool> saved,
    });

class $$CardProgressTableFilterComposer
    extends Composer<_$AppDatabase, $CardProgressTable> {
  $$CardProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get liked => $composableBuilder(
    column: $table.liked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $CardProgressTable> {
  $$CardProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get liked => $composableBuilder(
    column: $table.liked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardProgressTable> {
  $$CardProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<int> get box =>
      $composableBuilder(column: $table.box, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get liked =>
      $composableBuilder(column: $table.liked, builder: (column) => column);

  GeneratedColumn<bool> get saved =>
      $composableBuilder(column: $table.saved, builder: (column) => column);
}

class $$CardProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardProgressTable,
          CardProgressRow,
          $$CardProgressTableFilterComposer,
          $$CardProgressTableOrderingComposer,
          $$CardProgressTableAnnotationComposer,
          $$CardProgressTableCreateCompanionBuilder,
          $$CardProgressTableUpdateCompanionBuilder,
          (
            CardProgressRow,
            BaseReferences<_$AppDatabase, $CardProgressTable, CardProgressRow>,
          ),
          CardProgressRow,
          PrefetchHooks Function()
        > {
  $$CardProgressTableTableManager(_$AppDatabase db, $CardProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<int> box = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<bool> liked = const Value.absent(),
                Value<bool> saved = const Value.absent(),
              }) => CardProgressCompanion(
                cardId: cardId,
                box: box,
                dueAt: dueAt,
                lastReviewedAt: lastReviewedAt,
                liked: liked,
                saved: saved,
              ),
          createCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<int> box = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<bool> liked = const Value.absent(),
                Value<bool> saved = const Value.absent(),
              }) => CardProgressCompanion.insert(
                cardId: cardId,
                box: box,
                dueAt: dueAt,
                lastReviewedAt: lastReviewedAt,
                liked: liked,
                saved: saved,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardProgressTable, CardProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CardProgressTable,
                    CardProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardProgressTable,
      CardProgressRow,
      $$CardProgressTableFilterComposer,
      $$CardProgressTableOrderingComposer,
      $$CardProgressTableAnnotationComposer,
      $$CardProgressTableCreateCompanionBuilder,
      $$CardProgressTableUpdateCompanionBuilder,
      (
        CardProgressRow,
        BaseReferences<_$AppDatabase, $CardProgressTable, CardProgressRow>,
      ),
      CardProgressRow,
      PrefetchHooks Function()
    >;
typedef $$LessonProgressTableCreateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<int> lessonId,
      Value<bool> completed,
      Value<int?> score,
      Value<DateTime?> completedAt,
    });
typedef $$LessonProgressTableUpdateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<int> lessonId,
      Value<bool> completed,
      Value<int?> score,
      Value<DateTime?> completedAt,
    });

class $$LessonProgressTableFilterComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$LessonProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonProgressTable,
          LessonProgressRow,
          $$LessonProgressTableFilterComposer,
          $$LessonProgressTableOrderingComposer,
          $$LessonProgressTableAnnotationComposer,
          $$LessonProgressTableCreateCompanionBuilder,
          $$LessonProgressTableUpdateCompanionBuilder,
          (
            LessonProgressRow,
            BaseReferences<
              _$AppDatabase,
              $LessonProgressTable,
              LessonProgressRow
            >,
          ),
          LessonProgressRow,
          PrefetchHooks Function()
        > {
  $$LessonProgressTableTableManager(
    _$AppDatabase db,
    $LessonProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> lessonId = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => LessonProgressCompanion(
                lessonId: lessonId,
                completed: completed,
                score: score,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> lessonId = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => LessonProgressCompanion.insert(
                lessonId: lessonId,
                completed: completed,
                score: score,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LessonProgressTable, LessonProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LessonProgressTable,
                    LessonProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonProgressTable,
      LessonProgressRow,
      $$LessonProgressTableFilterComposer,
      $$LessonProgressTableOrderingComposer,
      $$LessonProgressTableAnnotationComposer,
      $$LessonProgressTableCreateCompanionBuilder,
      $$LessonProgressTableUpdateCompanionBuilder,
      (
        LessonProgressRow,
        BaseReferences<_$AppDatabase, $LessonProgressTable, LessonProgressRow>,
      ),
      LessonProgressRow,
      PrefetchHooks Function()
    >;
typedef $$ReadingPositionsTableCreateCompanionBuilder =
    ReadingPositionsCompanion Function({
      Value<int> lessonId,
      required String blockId,
      required double progress,
      required DateTime updatedAt,
    });
typedef $$ReadingPositionsTableUpdateCompanionBuilder =
    ReadingPositionsCompanion Function({
      Value<int> lessonId,
      Value<String> blockId,
      Value<double> progress,
      Value<DateTime> updatedAt,
    });

class $$ReadingPositionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingPositionsTable> {
  $$ReadingPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingPositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingPositionsTable> {
  $$ReadingPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingPositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingPositionsTable> {
  $$ReadingPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingPositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingPositionsTable,
          ReadingPositionRow,
          $$ReadingPositionsTableFilterComposer,
          $$ReadingPositionsTableOrderingComposer,
          $$ReadingPositionsTableAnnotationComposer,
          $$ReadingPositionsTableCreateCompanionBuilder,
          $$ReadingPositionsTableUpdateCompanionBuilder,
          (
            ReadingPositionRow,
            BaseReferences<
              _$AppDatabase,
              $ReadingPositionsTable,
              ReadingPositionRow
            >,
          ),
          ReadingPositionRow,
          PrefetchHooks Function()
        > {
  $$ReadingPositionsTableTableManager(
    _$AppDatabase db,
    $ReadingPositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingPositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> lessonId = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReadingPositionsCompanion(
                lessonId: lessonId,
                blockId: blockId,
                progress: progress,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> lessonId = const Value.absent(),
                required String blockId,
                required double progress,
                required DateTime updatedAt,
              }) => ReadingPositionsCompanion.insert(
                lessonId: lessonId,
                blockId: blockId,
                progress: progress,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingPositionsTable, ReadingPositionRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ReadingPositionsTable,
                    ReadingPositionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingPositionsTable,
      ReadingPositionRow,
      $$ReadingPositionsTableFilterComposer,
      $$ReadingPositionsTableOrderingComposer,
      $$ReadingPositionsTableAnnotationComposer,
      $$ReadingPositionsTableCreateCompanionBuilder,
      $$ReadingPositionsTableUpdateCompanionBuilder,
      (
        ReadingPositionRow,
        BaseReferences<
          _$AppDatabase,
          $ReadingPositionsTable,
          ReadingPositionRow
        >,
      ),
      ReadingPositionRow,
      PrefetchHooks Function()
    >;
typedef $$StudyDaysTableCreateCompanionBuilder = StudyDaysCompanion Function({
  required String day,
  Value<int> seconds,
  Value<int> rowid,
});
typedef $$StudyDaysTableUpdateCompanionBuilder = StudyDaysCompanion Function({
  Value<String> day,
  Value<int> seconds,
  Value<int> rowid,
});

class $$StudyDaysTableFilterComposer
    extends Composer<_$AppDatabase, $StudyDaysTable> {
  $$StudyDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudyDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyDaysTable> {
  $$StudyDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudyDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyDaysTable> {
  $$StudyDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get seconds =>
      $composableBuilder(column: $table.seconds, builder: (column) => column);
}

class $$StudyDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyDaysTable,
          StudyDayRow,
          $$StudyDaysTableFilterComposer,
          $$StudyDaysTableOrderingComposer,
          $$StudyDaysTableAnnotationComposer,
          $$StudyDaysTableCreateCompanionBuilder,
          $$StudyDaysTableUpdateCompanionBuilder,
          (
            StudyDayRow,
            BaseReferences<_$AppDatabase, $StudyDaysTable, StudyDayRow>,
          ),
          StudyDayRow,
          PrefetchHooks Function()
        > {
  $$StudyDaysTableTableManager(_$AppDatabase db, $StudyDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> day = const Value.absent(),
            Value<int> seconds = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => StudyDaysCompanion(day: day, seconds: seconds, rowid: rowid),
          createCompanionCallback:
              ({
                required String day,
                Value<int> seconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyDaysCompanion.insert(
                day: day,
                seconds: seconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudyDaysTable, StudyDayRow>(table),
                  BaseReferences<_$AppDatabase, $StudyDaysTable, StudyDayRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudyDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyDaysTable,
      StudyDayRow,
      $$StudyDaysTableFilterComposer,
      $$StudyDaysTableOrderingComposer,
      $$StudyDaysTableAnnotationComposer,
      $$StudyDaysTableCreateCompanionBuilder,
      $$StudyDaysTableUpdateCompanionBuilder,
      (
        StudyDayRow,
        BaseReferences<_$AppDatabase, $StudyDaysTable, StudyDayRow>,
      ),
      StudyDayRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String opId,
  required int seq,
  required String kind,
  required String payloadJson,
  Value<String?> replaceKey,
  Value<int> attempts,
  required DateTime createdAt,
  required DateTime nextAttemptAt,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> opId,
  Value<int> seq,
  Value<String> kind,
  Value<String> payloadJson,
  Value<String?> replaceKey,
  Value<int> attempts,
  Value<DateTime> createdAt,
  Value<DateTime> nextAttemptAt,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replaceKey => $composableBuilder(
    column: $table.replaceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replaceKey => $composableBuilder(
    column: $table.replaceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replaceKey => $composableBuilder(
    column: $table.replaceKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> opId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> replaceKey = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                opId: opId,
                seq: seq,
                kind: kind,
                payloadJson: payloadJson,
                replaceKey: replaceKey,
                attempts: attempts,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String opId,
                required int seq,
                required String kind,
                required String payloadJson,
                Value<String?> replaceKey = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                required DateTime createdAt,
                required DateTime nextAttemptAt,
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                opId: opId,
                seq: seq,
                kind: kind,
                payloadJson: payloadJson,
                replaceKey: replaceKey,
                attempts: attempts,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder = KeyValuesCompanion Function({
  required String name,
  required String value,
  Value<int> rowid,
});
typedef $$KeyValuesTableUpdateCompanionBuilder = KeyValuesCompanion Function({
  Value<String> name,
  Value<String> value,
  Value<int> rowid,
});

class $$KeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValueRow,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (
            KeyValueRow,
            BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValueRow>,
          ),
          KeyValueRow,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion(name: name, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String name,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion.insert(
                name: name,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValueRow>(table),
                  BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValueRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValueRow,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (
        KeyValueRow,
        BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValueRow>,
      ),
      KeyValueRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ModulesTableTableManager get modules =>
      $$ModulesTableTableManager(_db, _db.modules);
  $$LessonsTableTableManager get lessons =>
      $$LessonsTableTableManager(_db, _db.lessons);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
  $$ResourcesTableTableManager get resources =>
      $$ResourcesTableTableManager(_db, _db.resources);
  $$GlossaryEntriesTableTableManager get glossaryEntries =>
      $$GlossaryEntriesTableTableManager(_db, _db.glossaryEntries);
  $$CardProgressTableTableManager get cardProgress =>
      $$CardProgressTableTableManager(_db, _db.cardProgress);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(_db, _db.lessonProgress);
  $$ReadingPositionsTableTableManager get readingPositions =>
      $$ReadingPositionsTableTableManager(_db, _db.readingPositions);
  $$StudyDaysTableTableManager get studyDays =>
      $$StudyDaysTableTableManager(_db, _db.studyDays);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
}
