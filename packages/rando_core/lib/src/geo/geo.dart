import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;

/// Axis-aligned bounding box in WGS84 degrees.
class GeoBounds {
  const GeoBounds({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  LatLng get center => LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  LatLng get southWest => LatLng(minLat, minLng);
  LatLng get northEast => LatLng(maxLat, maxLng);

  bool contains(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLng &&
      p.longitude <= maxLng;

  GeoBounds extend(GeoBounds other) => GeoBounds(
        minLat: math.min(minLat, other.minLat),
        minLng: math.min(minLng, other.minLng),
        maxLat: math.max(maxLat, other.maxLat),
        maxLng: math.max(maxLng, other.maxLng),
      );

  /// Grows the box by [meters] on each side (approximate).
  GeoBounds pad(double meters) {
    final dLat = meters / 111320.0;
    final dLng =
        meters / (111320.0 * math.cos(center.latitude * math.pi / 180));
    return GeoBounds(
      minLat: minLat - dLat,
      minLng: minLng - dLng,
      maxLat: maxLat + dLat,
      maxLng: maxLng + dLng,
    );
  }

  static GeoBounds? fromPoints(Iterable<LatLng> points) {
    double? minLat, minLng, maxLat, maxLng;
    for (final p in points) {
      minLat = minLat == null ? p.latitude : math.min(minLat, p.latitude);
      maxLat = maxLat == null ? p.latitude : math.max(maxLat, p.latitude);
      minLng = minLng == null ? p.longitude : math.min(minLng, p.longitude);
      maxLng = maxLng == null ? p.longitude : math.max(maxLng, p.longitude);
    }
    if (minLat == null) return null;
    return GeoBounds(
      minLat: minLat,
      minLng: minLng!,
      maxLat: maxLat!,
      maxLng: maxLng!,
    );
  }

  Map<String, dynamic> toMap() => {
        'minLat': minLat,
        'minLng': minLng,
        'maxLat': maxLat,
        'maxLng': maxLng,
      };

  static GeoBounds? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return GeoBounds(
      minLat: (m['minLat'] as num).toDouble(),
      minLng: (m['minLng'] as num).toDouble(),
      maxLat: (m['maxLat'] as num).toDouble(),
      maxLng: (m['maxLng'] as num).toDouble(),
    );
  }
}

const double _earthRadiusM = 6371000.0;

/// Great-circle distance in meters.
double haversineM(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180;

/// Total length in meters of a set of polylines.
double tracksLengthM(List<List<LatLng>> tracks) {
  var total = 0.0;
  for (final line in tracks) {
    for (var i = 1; i < line.length; i++) {
      total += haversineM(line[i - 1], line[i]);
    }
  }
  return total;
}

/// Minimum distance in meters from [p] to any segment of [tracks].
/// Uses a local equirectangular projection, accurate enough for a few km.
double distanceToTracksM(LatLng p, List<List<LatLng>> tracks) {
  var best = double.infinity;
  final cosLat = math.cos(_rad(p.latitude));
  double px(LatLng q) => _rad(q.longitude - p.longitude) * cosLat;
  double py(LatLng q) => _rad(q.latitude - p.latitude);
  for (final line in tracks) {
    if (line.length == 1) {
      best = math.min(best, haversineM(p, line.first));
      continue;
    }
    for (var i = 1; i < line.length; i++) {
      final ax = px(line[i - 1]), ay = py(line[i - 1]);
      final bx = px(line[i]), by = py(line[i]);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      double t = 0;
      if (len2 > 0) {
        t = ((0 - ax) * dx + (0 - ay) * dy) / len2;
        t = t.clamp(0.0, 1.0);
      }
      final cx = ax + t * dx, cy = ay + t * dy;
      final d = math.sqrt(cx * cx + cy * cy) * _earthRadiusM;
      if (d < best) best = d;
    }
  }
  return best;
}

/// Fraction (0..1) of the first track already covered when standing at the
/// closest point to [p]. Useful for a simple progress indicator.
double progressAlongTracks(LatLng p, List<List<LatLng>> tracks) {
  if (tracks.isEmpty) return 0;
  final total = tracksLengthM(tracks);
  if (total == 0) return 0;
  var best = double.infinity;
  var bestDist = 0.0;
  var walked = 0.0;
  for (final line in tracks) {
    for (var i = 1; i < line.length; i++) {
      final a = line[i - 1], b = line[i];
      final segLen = haversineM(a, b);
      // Project p on segment a-b using distances (approximation).
      final dA = haversineM(p, a);
      final dB = haversineM(p, b);
      double t;
      if (segLen == 0) {
        t = 0;
      } else {
        t = ((dA * dA - dB * dB + segLen * segLen) / (2 * segLen)) / segLen;
        t = t.clamp(0.0, 1.0);
      }
      final along = walked + t * segLen;
      final d = distanceToTracksM(p, [
        [a, b]
      ]);
      if (d < best) {
        best = d;
        bestDist = along;
      }
      walked += segLen;
    }
  }
  return (bestDist / total).clamp(0.0, 1.0);
}

/// Serialises polylines to compact strings ("lat,lng;lat,lng;...") so they
/// can be stored in Firestore (which forbids nested arrays).
class TrackCodec {
  static List<String> encode(List<List<LatLng>> tracks) => tracks
      .map((line) => line
          .map((p) =>
              '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}')
          .join(';'))
      .toList();

  static List<List<LatLng>> decode(List<dynamic>? encoded) {
    if (encoded == null) return const [];
    final out = <List<LatLng>>[];
    for (final e in encoded) {
      if (e is! String || e.isEmpty) continue;
      final line = <LatLng>[];
      for (final pair in e.split(';')) {
        final idx = pair.indexOf(',');
        if (idx <= 0) continue;
        final lat = double.tryParse(pair.substring(0, idx));
        final lng = double.tryParse(pair.substring(idx + 1));
        if (lat == null || lng == null) continue;
        line.add(LatLng(lat, lng));
      }
      if (line.isNotEmpty) out.add(line);
    }
    return out;
  }
}

/// RGF93 / Lambert-93 (EPSG:2154) to WGS84 conversion.
class Lambert93 {
  static const String proj4Def =
      '+proj=lcc +lat_1=49 +lat_2=44 +lat_0=46.5 +lon_0=3 +x_0=700000 '
      '+y_0=6600000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs';

  static proj4.Projection? _src;
  static proj4.Projection? _dst;

  static void _init() {
    _src ??= proj4.Projection.get('EPSG:2154') ??
        proj4.Projection.add('EPSG:2154', proj4Def);
    _dst ??= proj4.Projection.get('EPSG:4326') ??
        proj4.Projection.add('EPSG:4326', '+proj=longlat +datum=WGS84 +no_defs');
  }

  static LatLng toWgs84(double x, double y) {
    _init();
    final p = _src!.transform(_dst!, proj4.Point(x: x, y: y));
    return LatLng(p.y, p.x);
  }
}

/// Joins consecutive segments of a MultiLineString into continuous polylines.
List<List<LatLng>> mergeSegments(List<List<LatLng>> segments) {
  const eps = 1e-7;
  bool same(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < eps &&
      (a.longitude - b.longitude).abs() < eps;
  final out = <List<LatLng>>[];
  for (final seg in segments) {
    if (seg.isEmpty) continue;
    if (out.isNotEmpty) {
      final cur = out.last;
      if (same(cur.last, seg.first)) {
        cur.addAll(seg.skip(1));
        continue;
      }
      if (same(cur.last, seg.last)) {
        cur.addAll(seg.reversed.skip(1));
        continue;
      }
    }
    out.add(List<LatLng>.from(seg));
  }
  // Second pass: segments are not always listed in order, so greedily chain
  // polylines whose endpoints touch.
  var joined = true;
  while (joined && out.length > 1) {
    joined = false;
    outer:
    for (var i = 0; i < out.length; i++) {
      for (var j = 0; j < out.length; j++) {
        if (i == j) continue;
        final a = out[i], b = out[j];
        if (same(a.last, b.first)) {
          a.addAll(b.skip(1));
        } else if (same(a.last, b.last)) {
          a.addAll(b.reversed.skip(1));
        } else if (same(a.first, b.last)) {
          a.insertAll(0, b.take(b.length - 1));
        } else if (same(a.first, b.first)) {
          a.insertAll(0, b.reversed.take(b.length - 1));
        } else {
          continue;
        }
        out.removeAt(j);
        joined = true;
        break outer;
      }
    }
  }
  return out;
}

/// Formats a distance for display ("850 m", "6,2 km").
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}

/// Formats a duration in hours ("2h", "2h30").
String formatDurationH(double? hours) {
  if (hours == null || hours <= 0) return '–';
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  if (m == 0) return '${h}h';
  return '${h}h${m.toString().padLeft(2, '0')}';
}
