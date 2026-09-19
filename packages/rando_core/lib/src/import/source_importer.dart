import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';

import '../geo/geo.dart';
import '../models/itineraire.dart';
import '../models/source.dart';

class ImportResult {
  ImportResult({
    required this.source,
    required this.itineraires,
    required this.warnings,
  });

  final RandoSource source;
  final List<Itineraire> itineraires;
  final List<String> warnings;
}

/// Parses a source file (zip or json) following the French national schema
/// "itinéraires de randonnée" (schema.data.gouv.fr) and converts it into
/// [Itineraire]s in WGS84.
class SourceImporter {
  /// Accepts either a zip containing one or more .json/.geojson files, or a
  /// raw JSON file.
  static ImportResult fromBytes(Uint8List bytes, {String? fileName}) {
    final isZip = bytes.length > 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
    if (isZip) return fromZipBytes(bytes, fileName: fileName);
    return fromJsonString(utf8.decode(bytes, allowMalformed: true),
        fileName: fileName);
  }

  static ImportResult fromZipBytes(Uint8List bytes, {String? fileName}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final jsonFiles = archive.files
        .where((f) =>
            f.isFile &&
            (f.name.toLowerCase().endsWith('.json') ||
                f.name.toLowerCase().endsWith('.geojson')))
        .toList();
    if (jsonFiles.isEmpty) {
      throw const FormatException('Aucun fichier .json trouvé dans le zip.');
    }
    ImportResult? merged;
    for (final f in jsonFiles) {
      final content = utf8.decode(f.content as List<int>, allowMalformed: true);
      final r = fromJsonString(content, fileName: fileName ?? f.name);
      if (merged == null) {
        merged = r;
      } else {
        merged = ImportResult(
          source: merged.source.copyWith(
              itineraireCount:
                  merged.itineraires.length + r.itineraires.length),
          itineraires: [...merged.itineraires, ...r.itineraires],
          warnings: [...merged.warnings, ...r.warnings],
        );
      }
    }
    return merged!;
  }

  static ImportResult fromJsonString(String json, {String? fileName}) {
    final decoded = jsonDecode(json);
    final items = _extractItems(decoded);
    final warnings = <String>[];
    final itineraires = <Itineraire>[];
    String? producteur;
    String? featureType;

    for (var i = 0; i < items.length; i++) {
      final raw = items[i];
      if (raw is! Map) continue;
      final props = <String, dynamic>{};
      if (raw['properties'] is Map) {
        props.addAll((raw['properties'] as Map).cast<String, dynamic>());
        props['json_geometry'] ??= raw['geometry'];
      } else {
        props.addAll(raw.cast<String, dynamic>());
      }
      producteur ??= _str(props['producteur']);
      featureType ??= _str(props['json_featuretype']);
      try {
        final it = _parseItineraire(props, i, fileName);
        if (it == null) {
          warnings.add('Élément $i ignoré : pas de géométrie exploitable.');
        } else {
          itineraires.add(it);
        }
      } catch (e) {
        warnings.add('Élément $i ignoré : $e');
      }
    }

    final sourceName = _prettyName(producteur ?? featureType ?? fileName ?? 'Source');
    final sourceId = slugify(producteur ?? featureType ?? fileName ?? 'source');
    final bounds = itineraires
        .map((e) => e.bounds)
        .fold<GeoBounds?>(null, (a, b) => a == null ? b : a.extend(b));
    final source = RandoSource(
      id: sourceId,
      name: sourceName,
      producteur: producteur ?? '',
      featureType: featureType ?? '',
      itineraireCount: itineraires.length,
      enabled: true,
      bounds: bounds,
      fileName: fileName,
    );
    // Stamp the resolved source id/name on each route.
    final stamped = itineraires
        .map((it) => Itineraire(
              id: it.id,
              sourceId: sourceId,
              sourceName: sourceName,
              nom: it.nom,
              tracks: it.tracks,
              start: it.start,
              bounds: it.bounds,
              pratique: it.pratique,
              typeItineraire: it.typeItineraire,
              communes: it.communes,
              depart: it.depart,
              arrivee: it.arrivee,
              dureeH: it.dureeH,
              balisage: it.balisage,
              longueurM: it.longueurM,
              difficulte: it.difficulte,
              altMax: it.altMax,
              altMin: it.altMin,
              denivelePositif: it.denivelePositif,
              deniveleNegatif: it.deniveleNegatif,
              instructions: it.instructions,
              presentation: it.presentation,
              presentationCourte: it.presentationCourte,
              themes: it.themes,
              recommandations: it.recommandations,
              accessibilite: it.accessibilite,
              accesRoutier: it.accesRoutier,
              transportsCommun: it.transportsCommun,
              parkingInfo: it.parkingInfo,
              parking: it.parking,
              dateCreation: it.dateCreation,
              dateModification: it.dateModification,
              medias: it.medias,
              typeSol: it.typeSol,
              pdipr: it.pdipr,
              url: it.url,
            ))
        .toList();
    return ImportResult(source: source, itineraires: stamped, warnings: warnings);
  }

  static List<dynamic> _extractItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      if (decoded['features'] is List) return decoded['features'] as List;
      if (decoded['itineraires'] is List) return decoded['itineraires'] as List;
      // Object keyed by index ("0", "1", ...)
      final keys = decoded.keys.toList()
        ..sort((a, b) =>
            (int.tryParse('$a') ?? 0).compareTo(int.tryParse('$b') ?? 0));
      return keys.map((k) => decoded[k]).toList();
    }
    throw const FormatException('Format JSON non reconnu.');
  }

  static Itineraire? _parseItineraire(
      Map<String, dynamic> p, int index, String? fileName) {
    final geom = _geometry(p);
    if (geom == null) return null;
    final lambert = _isLambert(p, geom);
    final segments = _segments(geom, lambert);
    final tracks = mergeSegments(segments);
    if (tracks.isEmpty || tracks.every((l) => l.isEmpty)) return null;

    final id = _str(p['uuid']) ??
        _str(p['id_local']) ??
        _str(p['id']) ??
        slugify('${fileName ?? 'src'}-$index');
    final start = tracks.first.first;
    final bounds = GeoBounds.fromPoints(tracks.expand((l) => l))!;

    return Itineraire(
      id: id,
      sourceId: '',
      sourceName: '',
      nom: _str(p['nom_itineraire']) ?? _str(p['nom']) ?? 'Itinéraire ${index + 1}',
      tracks: tracks,
      start: start,
      bounds: bounds,
      pratique: _str(p['pratique']),
      typeItineraire: _str(p['type_itineraire']),
      communes: _uniqueList(_str(p['communes_nom'])),
      depart: _str(p['depart']),
      arrivee: _str(p['arrivee']),
      dureeH: _hours(p['duree']),
      balisage: _str(p['balisage']),
      longueurM: _num(p['longueur']),
      difficulte: _str(p['difficulte']),
      altMax: _num(p['altitude_max']),
      altMin: _num(p['altitude_min']),
      denivelePositif: _num(p['denivele_positif']),
      deniveleNegatif: _num(p['denivele_negatif']),
      instructions: _str(p['instructions']),
      presentation: _str(p['presentation']),
      presentationCourte: _str(p['presentation_courte']),
      themes: _uniqueList(_str(p['themes'])),
      recommandations: _str(p['recommandations']),
      accessibilite: _str(p['accessibilite']),
      accesRoutier: _str(p['acces_routier']),
      transportsCommun: _str(p['transports_commun']),
      parkingInfo: _str(p['parking_info']),
      parking: _latLngFromString(_str(p['parking_geometrie'])),
      dateCreation: _str(p['date_creation']),
      dateModification: _str(p['date_modification']),
      medias: _medias(p['medias']),
      typeSol: _str(p['type_sol']),
      pdipr: _bool(p['pdipr_inscription']),
      url: _str(p['url']),
    );
  }

  static Map<String, dynamic>? _geometry(Map<String, dynamic> p) {
    final candidates = [p['json_geometry'], p['geometry'], p['geometrie']];
    for (final c in candidates) {
      if (c is Map && c['coordinates'] != null) return c.cast<String, dynamic>();
      if (c is String && c.trim().startsWith('{')) {
        try {
          final m = jsonDecode(c);
          if (m is Map && m['coordinates'] != null) {
            return m.cast<String, dynamic>();
          }
        } catch (_) {}
      }
    }
    return null;
  }

  static bool _isLambert(Map<String, dynamic> p, Map<String, dynamic> geom) {
    final crs = geom['crs'];
    if (crs is Map) {
      final name = '${(crs['properties'] as Map?)?['name'] ?? ''}';
      if (name.contains('2154')) return true;
      if (name.contains('4326')) return false;
    }
    final wkt = '${p['json_ogc_wkt_crs'] ?? ''}';
    if (wkt.contains('Lambert-93') || wkt.contains('2154')) return true;
    final geomStr = p['geometry'];
    if (geomStr is String && geomStr.contains('2154')) return true;
    // Heuristic: Lambert-93 coordinates are far outside [-180, 180].
    final first = _firstCoord(geom['coordinates']);
    if (first != null && (first[0].abs() > 360 || first[1].abs() > 360)) {
      return true;
    }
    return false;
  }

  static List<double>? _firstCoord(dynamic c) {
    if (c is List && c.isNotEmpty) {
      if (c[0] is num) {
        return c.take(2).map((e) => (e as num).toDouble()).toList();
      }
      return _firstCoord(c[0]);
    }
    return null;
  }

  static List<List<LatLng>> _segments(Map<String, dynamic> geom, bool lambert) {
    final type = '${geom['type'] ?? ''}'.toLowerCase();
    final coords = geom['coordinates'];
    LatLng conv(List c) {
      final x = (c[0] as num).toDouble();
      final y = (c[1] as num).toDouble();
      return lambert ? Lambert93.toWgs84(x, y) : LatLng(y, x);
    }

    List<LatLng> line(List l) =>
        l.whereType<List>().where((c) => c.length >= 2).map(conv).toList();

    switch (type) {
      case 'linestring':
        return [line(coords as List)];
      case 'multilinestring':
        return (coords as List).whereType<List>().map(line).toList();
      case 'point':
        return [
          [conv(coords as List)]
        ];
      case 'polygon':
        return (coords as List).whereType<List>().map(line).toList();
      default:
        return const [];
    }
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty || s == 'null' ? null : s;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  static double? _hours(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().toLowerCase().trim();
    final direct = double.tryParse(s.replaceAll(',', '.'));
    if (direct != null) return direct;
    final m = RegExp(r'(\d+)\s*h\s*(\d*)').firstMatch(s);
    if (m != null) {
      final h = double.parse(m.group(1)!);
      final min = double.tryParse(m.group(2) ?? '') ?? 0;
      return h + min / 60;
    }
    return null;
  }

  static bool _bool(dynamic v) {
    if (v is bool) return v;
    final s = '$v'.toLowerCase();
    return s == 'true' || s == '1' || s == 'oui';
  }

  static List<String> _uniqueList(String? s) {
    if (s == null) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final part in s.split(RegExp(r'[,;|]'))) {
      final t = part.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      out.add(t);
    }
    return out;
  }

  static LatLng? _latLngFromString(String? s) {
    if (s == null) return null;
    final parts = s.split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return null;
    final a = double.tryParse(parts[0]);
    final b = double.tryParse(parts[1]);
    if (a == null || b == null) return null;
    // "lat, lng" in the schema; swap if it obviously is "lng lat".
    if (a.abs() <= 90 && b.abs() <= 180) return LatLng(a, b);
    if (b.abs() <= 90 && a.abs() <= 180) return LatLng(b, a);
    return null;
  }

  static List<MediaItem> _medias(dynamic v) {
    if (v is Map) {
      final m = MediaItem.fromMap(v.cast<String, dynamic>());
      return m == null ? const [] : [m];
    }
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => MediaItem.fromMap(e.cast<String, dynamic>()))
          .whereType<MediaItem>()
          .toList();
    }
    return const [];
  }

  static String _prettyName(String s) {
    var out = s.replaceAll('_', ' ').trim();
    out = out.replaceFirst(RegExp(r'^itinerairerandonnee\s*', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\.(zip|json|geojson)$', caseSensitive: false), '');
    return out.isEmpty ? s : out;
  }
}

/// Turns any label into a Firestore-friendly id ("cc-des-lisieres-de-l-oise").
String slugify(String input) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  var s = input.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s.replaceAll(RegExp(r'\.(zip|json|geojson)$'), '');
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'source' : s;
}
