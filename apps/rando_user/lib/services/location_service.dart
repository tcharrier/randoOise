import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Thin wrapper around geolocator with French error messages.
class LocationService {
  Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'La localisation est désactivée sur cet appareil.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return 'Autorisation de localisation refusée.';
    }
    if (perm == LocationPermission.deniedForever) {
      return "Localisation refusée définitivement : activez-la dans les réglages de l'appareil.";
    }
    return null;
  }

  Future<LatLng?> currentPosition() async {
    try {
      if (await ensurePermission() != null) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return LatLng(last.latitude, last.longitude);
      } catch (_) {}
      return null;
    }
  }

  Stream<Position> stream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3,
        ),
      );
}
