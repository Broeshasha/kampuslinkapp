import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../features/onboarding/onboarding_status.dart';
import '../catalog/catalog.dart';

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

List<Map<String, dynamic>> _maps(Object? v) => [
  for (final e in (v is List ? v : const <Object?>[]))
    if (e is Map) e.cast<String, dynamic>(),
];

/// A speciality the app offers now, with ONLY its offered years.
class OfferedSpeciality {
  const OfferedSpeciality({
    required this.id,
    required this.name,
    required this.levels,
    this.learnEnabled = true,
  });

  factory OfferedSpeciality.fromMap(Map<String, dynamic> m) {
    final levels = [for (final l in _maps(m['levels'])) CatalogLevel.fromMap(l)]
      ..sort((a, b) => a.position.compareTo(b.position));
    return OfferedSpeciality(
      id: _int(m['id']) ?? 0,
      name: '${m['name'] ?? ''}',
      levels: levels,
      learnEnabled: m['learn_enabled'] != false,
    );
  }

  final int id;
  final String name;
  final List<CatalogLevel> levels;
  final bool learnEnabled;

  CatalogLevel? level(String? year) {
    for (final l in levels) {
      if (l.year == year) {
        return l;
      }
    }
    return null;
  }
}

/// get_onboarding_options(): nothing about studies is written in the app.
class OnboardingOffers {
  const OnboardingOffers({
    this.universities = const [],
    this.specialities = const [],
    this.others = const [],
    this.waitlisted = false,
  });

  factory OnboardingOffers.fromMap(Map<String, dynamic> m) => OnboardingOffers(
    universities: [
      for (final u in _maps(m['universities']))
        if (_int(u['id']) != null) (id: _int(u['id'])!, name: '${u['name']}'),
    ],
    specialities: [
      for (final s in _maps(m['specialities'])) OfferedSpeciality.fromMap(s),
    ],
    others: [
      for (final s in _maps(m['other_specialities']))
        if (_int(s['id']) != null) (id: _int(s['id'])!, name: '${s['name']}'),
    ],
    waitlisted: m['waitlisted'] == true,
  );

  final List<({int id, String name})> universities;
  final List<OfferedSpeciality> specialities;
  final List<({int id, String name})> others;
  final bool waitlisted;

  OfferedSpeciality? speciality(int? id) {
    for (final s in specialities) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  /// Is this speciality (and, when given, this year) offered now?
  bool offers(int? specialityId, String? year) {
    final s = speciality(specialityId);
    if (s == null) {
      return false;
    }
    return year == null || year.isEmpty || s.level(year) != null;
  }
}

final onboardingOffersProvider = FutureProvider<OnboardingOffers>((ref) async {
  final raw = await ref.watch(onboardingOptionsProvider.future);
  return OnboardingOffers.fromMap(raw);
});

/// What the student asked to be told about (join_waitlist), kept on the
/// phone for the "coming soon" screen and the daily check.
class WaitlistEntry {
  const WaitlistEntry({
    this.specialityId,
    this.specialityText,
    this.year,
    this.universityId,
    required this.name,
  });

  factory WaitlistEntry.fromJson(Map<String, dynamic> j) => WaitlistEntry(
    specialityId: _int(j['speciality_id']),
    specialityText: j['speciality_text'] as String?,
    year: j['year'] as String?,
    universityId: _int(j['university_id']),
    name: '${j['name'] ?? ''}',
  );

  final int? specialityId;
  final String? specialityText;
  final String? year;
  final int? universityId;

  /// Shown to the student ("Mining engineering is now on KampusLink").
  final String name;

  Map<String, Object?> toJson() => {
    'speciality_id': specialityId,
    'speciality_text': specialityText,
    'year': year,
    'university_id': universityId,
    'name': name,
  };
}

const waitlistKey = 'waitlist_v1';

WaitlistEntry? readWaitlist(SharedPreferences prefs) {
  final raw = prefs.getString(waitlistKey);
  if (raw == null) {
    return null;
  }
  try {
    final v = jsonDecode(raw);
    return v is Map ? WaitlistEntry.fromJson(v.cast<String, dynamic>()) : null;
  } on FormatException {
    return null;
  }
}

/// join_waitlist and set_study_profile (backend files 24-25).
class StudiesApi {
  StudiesApi(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Future<void> joinWaitlist({
    int? specialityId,
    String? specialityText,
    String? year,
    int? universityId,
  }) async {
    await _client
        .rpc(
          'join_waitlist',
          params: {
            'p_speciality_id': specialityId,
            'p_speciality_text': specialityText,
            'p_year': year,
            'p_university_id': universityId,
          },
        )
        .timeout(_timeout);
  }

  /// Returns get_me().
  Future<Map<String, dynamic>> setStudyProfile({
    required int specialityId,
    required String year,
    int? semester,
  }) async {
    final v = await _client
        .rpc(
          'set_study_profile',
          params: {
            'p_speciality': specialityId,
            'p_year': year,
            'p_semester': semester,
          },
        )
        .timeout(_timeout);
    return v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
  }
}

final studiesApiProvider = Provider<StudiesApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : StudiesApi(client);
});

/// Saves the waitlist choice on the phone (and the server when it can).
Future<void> rememberWaitlist(WidgetRef ref, WaitlistEntry entry) async {
  await ref
      .read(sharedPrefsProvider)
      .setString(waitlistKey, jsonEncode(entry.toJson()));
}
