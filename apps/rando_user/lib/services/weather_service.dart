import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Weather condition families derived from WMO codes (Open-Meteo).
enum WeatherKind {
  clear('Ciel dégagé'),
  mainlyClear('Peu nuageux'),
  partlyCloudy('Partiellement nuageux'),
  overcast('Couvert'),
  fog('Brouillard'),
  drizzle('Bruine'),
  rain('Pluie'),
  heavyRain('Fortes pluies'),
  snow('Neige'),
  thunder('Orage');

  const WeatherKind(this.label);
  final String label;

  bool get isWet => this == drizzle || this == rain || this == heavyRain || this == thunder;

  static WeatherKind fromWmo(int code) {
    if (code == 0) return clear;
    if (code == 1) return mainlyClear;
    if (code == 2) return partlyCloudy;
    if (code == 3) return overcast;
    if (code == 45 || code == 48) return fog;
    if (code >= 51 && code <= 57) return drizzle;
    if (code == 61 || code == 63 || code == 66 || code == 80) return rain;
    if (code == 65 || code == 67 || code == 81 || code == 82) return heavyRain;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) return snow;
    if (code >= 95) return thunder;
    return partlyCloudy;
  }
}

class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.tempC,
    required this.kind,
    required this.precipProbability,
    required this.precipMm,
    required this.windKmh,
    required this.isDay,
  });

  final DateTime time;
  final double tempC;
  final WeatherKind kind;
  final int precipProbability;
  final double precipMm;
  final double windKmh;
  final bool isDay;
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.fetchedAt,
    required this.now,
    required this.hours,
    required this.place,
  });

  final DateTime fetchedAt;
  final WeatherHour now;

  /// The next hours after [now] (5 by default).
  final List<WeatherHour> hours;
  final String place;

  bool get isStale => DateTime.now().difference(fetchedAt) > const Duration(minutes: 30);

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'place': place,
        'now': _hourToJson(now),
        'hours': hours.map(_hourToJson).toList(),
      };

  static Map<String, dynamic> _hourToJson(WeatherHour h) => {
        'time': h.time.toIso8601String(),
        'temp': h.tempC,
        'kind': h.kind.name,
        'pop': h.precipProbability,
        'mm': h.precipMm,
        'wind': h.windKmh,
        'day': h.isDay,
      };

  static WeatherHour _hourFromJson(Map<String, dynamic> j) => WeatherHour(
        time: DateTime.parse(j['time'] as String),
        tempC: (j['temp'] as num).toDouble(),
        kind: WeatherKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => WeatherKind.partlyCloudy),
        precipProbability: (j['pop'] as num?)?.toInt() ?? 0,
        precipMm: (j['mm'] as num?)?.toDouble() ?? 0,
        windKmh: (j['wind'] as num?)?.toDouble() ?? 0,
        isDay: (j['day'] as bool?) ?? true,
      );

  static WeatherSnapshot? fromJson(Map<String, dynamic> j) {
    try {
      return WeatherSnapshot(
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
        place: (j['place'] as String?) ?? 'Compiègne',
        now: _hourFromJson((j['now'] as Map).cast<String, dynamic>()),
        hours: ((j['hours'] as List?) ?? const [])
            .map((e) => _hourFromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Open-Meteo forecast for Compiègne, cached on the device so the tile still
/// shows the last known weather when offline.
class WeatherService extends ChangeNotifier {
  WeatherService(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        snapshot = WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  static const _key = 'weather_cache';
  static const double lat = 49.4178;
  static const double lng = 2.8264;
  static const String place = 'Compiègne';
  static const int hoursAhead = 5;

  final SharedPreferences _prefs;
  WeatherSnapshot? snapshot;
  bool loading = false;
  String? error;

  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    if (!force && snapshot != null && !snapshot!.isStale) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lng',
        'current': 'temperature_2m,weather_code,wind_speed_10m,is_day,precipitation',
        'hourly': 'temperature_2m,weather_code,precipitation_probability,precipitation,wind_speed_10m,is_day',
        'timezone': 'Europe/Paris',
        'forecast_days': '2',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final snap = _parse(j);
      snapshot = snap;
      await _prefs.setString(_key, jsonEncode(snap.toJson()));
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static WeatherSnapshot _parse(Map<String, dynamic> j) {
    final cur = (j['current'] as Map).cast<String, dynamic>();
    final now = DateTime.parse(cur['time'] as String);
    final nowHour = WeatherHour(
      time: now,
      tempC: (cur['temperature_2m'] as num).toDouble(),
      kind: WeatherKind.fromWmo((cur['weather_code'] as num).toInt()),
      precipProbability: 0,
      precipMm: (cur['precipitation'] as num?)?.toDouble() ?? 0,
      windKmh: (cur['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      isDay: ((cur['is_day'] as num?)?.toInt() ?? 1) == 1,
    );
    final h = (j['hourly'] as Map).cast<String, dynamic>();
    final times = (h['time'] as List).cast<String>();
    final temps = (h['temperature_2m'] as List).cast<num>();
    final codes = (h['weather_code'] as List).cast<num>();
    final pops = (h['precipitation_probability'] as List?)?.cast<num?>();
    final mms = (h['precipitation'] as List?)?.cast<num?>();
    final winds = (h['wind_speed_10m'] as List?)?.cast<num?>();
    final days = (h['is_day'] as List?)?.cast<num?>();
    final hours = <WeatherHour>[];
    for (var i = 0; i < times.length && hours.length < hoursAhead; i++) {
      final t = DateTime.parse(times[i]);
      if (!t.isAfter(now)) continue;
      hours.add(WeatherHour(
        time: t,
        tempC: temps[i].toDouble(),
        kind: WeatherKind.fromWmo(codes[i].toInt()),
        precipProbability: pops?[i]?.toInt() ?? 0,
        precipMm: mms?[i]?.toDouble() ?? 0,
        windKmh: winds?[i]?.toDouble() ?? 0,
        isDay: (days?[i]?.toInt() ?? 1) == 1,
      ));
    }
    return WeatherSnapshot(fetchedAt: DateTime.now(), now: nowHour, hours: hours, place: place);
  }
}
