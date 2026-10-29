import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/profile/offers.dart';
import 'package:kampuslink/data/profile/waitlist_check.dart';

void main() {
  final offers = OnboardingOffers.fromMap({
    'specialities': [
      {
        'id': 5,
        'name': 'Architecture',
        'levels': [
          {
            'year': 'L1',
            'position': 1,
            'semesters': [1, 2],
            'label': {},
          },
        ],
      },
    ],
  });

  test('waitlisted speciality (and year) now offered', () {
    const l1 = WaitlistEntry(specialityId: 5, year: 'L1', name: 'Architecture');
    const l3 = WaitlistEntry(specialityId: 5, year: 'L3', name: 'Architecture');
    const anyYear = WaitlistEntry(specialityId: 5, name: 'Architecture');
    const other = WaitlistEntry(specialityId: 9, name: 'Medicine');
    const typed = WaitlistEntry(specialityText: 'Geology', name: 'Geology');
    expect(waitlistNowOffered(offers, l1), isTrue);
    expect(waitlistNowOffered(offers, anyYear), isTrue);
    expect(waitlistNowOffered(offers, l3), isFalse);
    expect(waitlistNowOffered(offers, other), isFalse);
    expect(waitlistNowOffered(offers, typed), isFalse);
    expect(waitlistNowOffered(offers, null), isFalse);
  });

  test('the notification names the speciality in 3 languages', () {
    for (final lang in const ['fr', 'en', 'ar', 'xx']) {
      final t = waitlistTexts(lang, 'Architecture');
      expect(t.title, contains('Architecture'));
      expect(t.body, isNotEmpty);
    }
  });
}
