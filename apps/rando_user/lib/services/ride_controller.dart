import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rando_core/rando_core.dart';

import 'sorties_service.dart';

/// GPS tracking of one outing along a route: start, pause, resume, stop.
/// Ported from CycloARC's RideNotifier and shared by hikes and rides.
///
/// The controller is a singleton owned by the app state, so leaving the
/// navigation screen does not interrupt the recording.
class RideController extends ChangeNotifier {
  Itineraire? itineraire;
  bool isActive = false;
  bool isPaused = false;
  DateTime? startTime;
  int pausedDurationMs = 0;
  final List<Position> positions = [];
  Position? currentPosition;
  String? gpsError;

  StreamSubscription<Position>? _sub;
  Timer? _timer;
  DateTime? _pauseStart;

  // ------------------------------------------------------------- computed

  int get elapsedSeconds {
    if (startTime == null) return 0;
    final paused = pausedDurationMs +
        (isPaused && _pauseStart != null ? DateTime.now().difference(_pauseStart!).inMilliseconds : 0);
    return math.max(0, (DateTime.now().difference(startTime!).inMilliseconds - paused) ~/ 1000);
  }

  double get distanceKm {
    if (positions.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < positions.length; i++) {
      total += haversineM(
        LatLng(positions[i - 1].latitude, positions[i - 1].longitude),
        LatLng(positions[i].latitude, positions[i].longitude),
      );
    }
    return total / 1000;
  }

  double get currentSpeedKmh {
    final p = currentPosition;
    if (p == null || p.speed < 0) return 0;
    return p.speed * 3.6;
  }

  double get avgSpeedKmh {
    final secs = elapsedSeconds;
    if (secs == 0 || distanceKm == 0) return 0;
    return distanceKm / (secs / 3600);
  }

  double get maxSpeedKmh {
    var m = 0.0;
    for (final p in positions) {
      if (p.speed > 0 && p.speed * 3.6 > m) m = p.speed * 3.6;
    }
    return m;
  }

  LatLng? get currentLatLng =>
      currentPosition == null ? null : LatLng(currentPosition!.latitude, currentPosition!.longitude);

  /// Distance to the reference route in meters (null without position).
  double? get offTrackM {
    final p = currentLatLng;
    final it = itineraire;
    if (p == null || it == null) return null;
    return distanceToTracksM(p, it.tracks);
  }

  /// Fraction of the route already covered, from the closest point of the
  /// track to the current position.
  double? get progress {
    final p = currentLatLng;
    final it = itineraire;
    if (p == null || it == null) return null;
    return progressAlongTracks(p, it.tracks);
  }

  List<LatLng> get trail => positions.map((p) => LatLng(p.latitude, p.longitude)).toList();

  // ------------------------------------------------------------ lifecycle

  Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'La localisation est désactivée sur cet appareil.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return 'Autorisation de localisation refusée.';
    if (perm == LocationPermission.deniedForever) {
      return "Localisation refusée définitivement : activez-la dans les réglages de l'appareil.";
    }
    return null;
  }

  /// Starts recording. Returns an error message when GPS is unavailable.
  Future<String?> start(Itineraire it) async {
    final err = await ensurePermission();
    if (err != null) {
      gpsError = err;
      notifyListeners();
      return err;
    }
    _cleanup();
    itineraire = it;
    isActive = true;
    isPaused = false;
    startTime = DateTime.now();
    pausedDurationMs = 0;
    positions.clear();
    gpsError = null;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
    ).listen((p) {
      currentPosition = p;
      if (isActive && !isPaused && p.accuracy <= 50) positions.add(p);
      notifyListeners();
    }, onError: (e) {
      gpsError = 'GPS indisponible : $e';
      notifyListeners();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
    return null;
  }

  void pause() {
    if (!isActive || isPaused) return;
    isPaused = true;
    _pauseStart = DateTime.now();
    notifyListeners();
  }

  void resume() {
    if (!isActive || !isPaused) return;
    if (_pauseStart != null) {
      pausedDurationMs += DateTime.now().difference(_pauseStart!).inMilliseconds;
      _pauseStart = null;
    }
    isPaused = false;
    notifyListeners();
  }

  /// Stops recording and returns the outing (not yet saved).
  Sortie? stop() {
    final it = itineraire;
    if (!isActive || it == null) return null;
    if (isPaused) resume();
    final s = Sortie(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      itineraireId: it.id,
      itineraireNom: it.titre,
      activite: it.activite,
      startedAt: startTime ?? DateTime.now(),
      endedAt: DateTime.now(),
      durationSeconds: elapsedSeconds,
      distanceKm: distanceKm,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      trajectory: trail,
    );
    _reset();
    return s;
  }

  void cancel() => _reset();

  void _reset() {
    _cleanup();
    itineraire = null;
    isActive = false;
    isPaused = false;
    startTime = null;
    pausedDurationMs = 0;
    positions.clear();
    notifyListeners();
  }

  void _cleanup() {
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _pauseStart = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
