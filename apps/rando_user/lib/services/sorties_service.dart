import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:rando_core/rando_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A completed outing (hike or ride) kept on the device.
class Sortie {
  const Sortie({
    required this.id,
    required this.itineraireId,
    required this.itineraireNom,
    required this.activite,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.trajectory,
    this.note = '',
  });

  final String id;
  final String itineraireId;
  final String itineraireNom;
  final Activite activite;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final List<LatLng> trajectory;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itineraireId': itineraireId,
        'itineraireNom': itineraireNom,
        'activite': activite.code,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'distanceKm': distanceKm,
        'avgSpeedKmh': avgSpeedKmh,
        'maxSpeedKmh': maxSpeedKmh,
        'trajectory': trajectory.map((p) => [p.longitude, p.latitude]).toList(),
        'note': note,
      };

  static Sortie? fromJson(Map<String, dynamic> j) {
    try {
      return Sortie(
        id: j['id'] as String,
        itineraireId: (j['itineraireId'] ?? '') as String,
        itineraireNom: (j['itineraireNom'] ?? '') as String,
        activite: Activite.fromCode(j['activite'] as String?),
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        avgSpeedKmh: (j['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
        maxSpeedKmh: (j['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
        trajectory: ((j['trajectory'] as List?) ?? const [])
            .whereType<List>()
            .where((p) => p.length >= 2)
            .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
            .toList(),
        note: (j['note'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Sortie copyWith({String? note}) => Sortie(
        id: id,
        itineraireId: itineraireId,
        itineraireNom: itineraireNom,
        activite: activite,
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
        distanceKm: distanceKm,
        avgSpeedKmh: avgSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
        trajectory: trajectory,
        note: note ?? this.note,
      );
}

/// Outing history, stored locally (SharedPreferences JSON). Saving an outing
/// is always the user's choice at the end of the tracking.
class SortiesService extends ChangeNotifier {
  SortiesService(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _items = (jsonDecode(raw) as List)
            .map((e) => Sortie.fromJson((e as Map).cast<String, dynamic>()))
            .whereType<Sortie>()
            .toList();
      } catch (_) {}
    }
  }

  static const _key = 'sorties';
  final SharedPreferences _prefs;
  List<Sortie> _items = [];

  /// Most recent first.
  List<Sortie> get all => [..._items]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
  int get count => _items.length;
  double get totalKm => _items.fold(0.0, (s, e) => s + e.distanceKm);
  int get totalSeconds => _items.fold(0, (s, e) => s + e.durationSeconds);

  List<Sortie> forItineraire(String id) => all.where((s) => s.itineraireId == id).toList();

  Sortie? byId(String id) {
    for (final s in _items) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> add(Sortie s) async {
    _items = [..._items, s];
    await _save();
  }

  Future<void> updateNote(String id, String note) async {
    _items = _items.map((s) => s.id == id ? s.copyWith(note: note) : s).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    _items = _items.where((s) => s.id != id).toList();
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}
