import 'dart:math' as math;

/// MOT-1: approximate Maghrib / Isha for the "after Maghrib / after Isha"
/// study anchors, computed on the phone (no location permission, no call).
/// Standard solar formula (NOAA), Isha at the sun 17 deg below the horizon.
/// Accuracy: a few minutes for the place given; enough for a study anchor.
/// v1 uses Algiers for every wilaya (south-west wilayas are up to ~40 min
/// later); a wilaya coordinate table comes with the server push (MOT-3).
class PrayerTimes {
  const PrayerTimes({required this.maghrib, required this.isha});

  /// Local wall-clock times (UTC + [utcOffsetHours]) on the given day.
  final DateTime maghrib;
  final DateTime isha;
}

const algiersLat = 36.7538;
const algiersLon = 3.0588;

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// Minutes after local midnight when the sun reaches [altitude] degrees in
/// the evening, or null (polar day / night - never in Algeria).
double? _eveningMinutes(DateTime day, double lat, double lon, double altitude, double tz) {
  final start = DateTime.utc(day.year, 1, 1);
  final n = DateTime.utc(day.year, day.month, day.day).difference(start).inDays + 1;
  final g = 2 * math.pi / 365 * (n - 1 + 0.5);
  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(g) -
          0.032077 * math.sin(g) -
          0.014615 * math.cos(2 * g) -
          0.040849 * math.sin(2 * g));
  final decl = 0.006918 -
      0.399912 * math.cos(g) +
      0.070257 * math.sin(g) -
      0.006758 * math.cos(2 * g) +
      0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) +
      0.00148 * math.sin(3 * g);
  final cosH = (math.sin(_rad(altitude)) - math.sin(_rad(lat)) * math.sin(decl)) /
      (math.cos(_rad(lat)) * math.cos(decl));
  if (cosH < -1 || cosH > 1) return null;
  final hourAngle = _deg(math.acos(cosH));
  final noon = 720 - 4 * lon - eqTime + tz * 60;
  return noon + 4 * hourAngle;
}

PrayerTimes prayerTimes(
  DateTime day, {
  double lat = algiersLat,
  double lon = algiersLon,
  double utcOffsetHours = 1,
}) {
  DateTime at(double? minutes, double fallback) {
    final m = (minutes ?? fallback).round();
    return DateTime(day.year, day.month, day.day).add(Duration(minutes: m));
  }

  // Sunset: upper limb + refraction = -0.833 deg.
  final maghrib = _eveningMinutes(day, lat, lon, -0.833, utcOffsetHours);
  final isha = _eveningMinutes(day, lat, lon, -17, utcOffsetHours);
  return PrayerTimes(
    maghrib: at(maghrib, 18 * 60),
    isha: at(isha, 19.5 * 60),
  );
}
