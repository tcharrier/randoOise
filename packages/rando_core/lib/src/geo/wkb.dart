import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Result of parsing one WKB geometry: WGS84 polylines plus, when the
/// geometry carries a Z coordinate, the matching elevations.
class WkbLines {
  const WkbLines({required this.lines, this.elevations});

  /// Polylines as (lat, lng).
  final List<List<LatLng>> lines;

  /// Same shape as [lines]; null when the geometry has no Z.
  final List<List<double>>? elevations;

  bool get hasElevation => elevations != null;
}

/// Minimal WKB reader for LineString (2) and MultiLineString (5), with or
/// without Z. Ported from the CycloARC parser; coordinates are expected in
/// WGS84 (lon, lat[, z]).
class WkbParser {
  WkbParser._();

  static WkbLines? parse(ByteData blob, int offset, int length) {
    if (length < 5 || offset + length > blob.lengthInBytes) return null;
    try {
      final endian = blob.getUint8(offset) == 1 ? Endian.little : Endian.big;
      final geomType = blob.getUint32(offset + 1, endian);
      final hasZ = geomType >= 1000;
      final baseType = hasZ ? geomType % 1000 : geomType;
      var pos = offset + 5;

      final lines = <List<LatLng>>[];
      final elevations = <List<double>>[];

      switch (baseType) {
        case 2:
          pos = _readLine(blob, pos, endian, hasZ, lines, elevations);
        case 5:
          final numLines = blob.getUint32(pos, endian);
          pos += 4;
          for (var i = 0; i < numLines; i++) {
            final innerEndian = blob.getUint8(pos) == 1 ? Endian.little : Endian.big;
            pos += 5; // byte order (1) + type (4)
            pos = _readLine(blob, pos, innerEndian, hasZ, lines, elevations);
          }
        default:
          return null;
      }
      return WkbLines(lines: lines, elevations: hasZ ? elevations : null);
    } catch (_) {
      return null;
    }
  }

  static int _readLine(
    ByteData blob,
    int pos,
    Endian endian,
    bool hasZ,
    List<List<LatLng>> lines,
    List<List<double>> elevations,
  ) {
    final numPoints = blob.getUint32(pos, endian);
    pos += 4;
    final coordSize = hasZ ? 24 : 16;
    final line = <LatLng>[];
    final zs = <double>[];
    for (var i = 0; i < numPoints; i++) {
      final x = blob.getFloat64(pos, endian);
      final y = blob.getFloat64(pos + 8, endian);
      line.add(LatLng(y, x));
      if (hasZ) zs.add(blob.getFloat64(pos + 16, endian));
      pos += coordSize;
    }
    if (line.isNotEmpty) {
      lines.add(line);
      elevations.add(zs);
    }
    return pos;
  }
}
