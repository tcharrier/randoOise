import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../geo/geo.dart';
import '../geo/wkb.dart';
import '../models/activite.dart';
import '../models/itineraire.dart';
import '../models/source.dart';

/// One itinerary of the official map "Plan des itinéraires cyclables de
/// l'ARC" (`assets/velo/plan_arc.json`): its number, name, colour and the
/// ids of the dataset rows that draw it.
class PlanArcEntry {
  const PlanArcEntry({
    required this.numero,
    required this.nom,
    required this.couleur,
    required this.longueurKm,
    this.datasetIds = const [],
  });

  /// Number printed in the badge on the plan (1..21).
  final int numero;

  /// Name as printed on the plan, in readable French ("Le Meux ◄► Rivecourt").
  final String nom;

  /// Colour of the route on the plan (ARGB).
  final int couleur;

  /// Length printed on the plan.
  final double longueurKm;

  /// Rows of `itineraries_min.jsonl` that draw this route, in drawing order.
  final List<String> datasetIds;

  /// Stable id of the resulting [Itineraire] (reports point to it).
  String get id => '${VeloDataset.sourceId}-$numero';

  /// Places named by [nom]: "A ◄► B par C" → [A, C, B], "A – B – C" → [A, B, C],
  /// a single name → [name].
  List<String> get etapes {
    final out = <String>[];
    for (final raw in nom.split(_separator)) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      final via = part.indexOf(' par ');
      if (via > 0) {
        out.add(part.substring(via + 5).trim());
        out.add(part.substring(0, via).trim());
      } else {
        out.add(part);
      }
    }
    return out.isEmpty ? [nom] : out;
  }

  String get depart => etapes.first;
  String get arrivee => etapes.last;

  static final RegExp _separator = RegExp(r'\s*(?:◄►|–)\s*');

  static PlanArcEntry? fromMap(Map<String, dynamic> m) {
    final numero = (m['numero'] as num?)?.toInt();
    final nom = m['nom']?.toString().trim();
    final couleur = parseCouleur(m['couleur']);
    if (numero == null || nom == null || nom.isEmpty || couleur == null) return null;
    return PlanArcEntry(
      numero: numero,
      nom: nom,
      couleur: couleur,
      longueurKm: (m['longueurKm'] as num?)?.toDouble() ?? 0,
      datasetIds: ((m['datasetIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }

  /// Entries of the decoded `plan_arc.json`, sorted by number.
  static List<PlanArcEntry> listFromJson(Map<String, dynamic> planJson) {
    final list = (planJson['itineraires'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => fromMap(e.cast<String, dynamic>()))
        .whereType<PlanArcEntry>()
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
  }

  /// "#1CC4F4" / "1CC4F4" → 0xFF1CC4F4; an int is returned as is.
  static int? parseCouleur(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    final hex = v.toString().trim().replaceFirst('#', '');
    final n = int.tryParse(hex, radix: 16);
    if (n == null) return null;
    return hex.length <= 6 ? (0xFF000000 | n) : n;
  }
}

/// The cycling network of the Agglomération de la Région de Compiègne, as
/// prepared by the CycloARC pipeline: one JSON line per route plus a WKB
/// blob holding every geometry.
///
/// With the official plan (`plan_arc.json`), the dataset rows are regrouped
/// into the numbered itineraries of the plan (ids `arc-velo-<n>`, plan name
/// and colour) and every other row becomes a "secondary" lane: drawn thin
/// and grey on maps, never listed.
class VeloDataset {
  VeloDataset._();

  static const String sourceId = 'arc-velo';
  static const String sourceName = 'Pistes cyclables ARC';

  /// Average cycling speed used for duration estimates.
  static const double speedKmh = 18;

  /// Colour of the secondary lanes (ARGB).
  static const int secondaryCouleur = 0xFF9A9A9A;

  /// Parses `itineraries_min.jsonl` + `geoms.wkb` into routes.
  ///
  /// When [planJson] (the decoded `plan_arc.json`) is given, one route is
  /// built per plan itinerary that has at least one matched dataset row and
  /// the unmatched rows are flagged [Itineraire.secondaire]. Without a plan,
  /// each dataset row is a route (legacy behaviour).
  static ({RandoSource source, List<Itineraire> itineraires, List<String> warnings}) parse(
    String jsonl,
    ByteData wkb, {
    Map<String, dynamic>? meta,
    Map<String, dynamic>? planJson,
  }) {
    final warnings = <String>[];
    final rows = <_Row>[];
    for (final raw in const LineSplitter().convert(jsonl)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      Map<String, dynamic> j;
      try {
        j = jsonDecode(line) as Map<String, dynamic>;
      } catch (e) {
        warnings.add('Ligne ignorée : $e');
        continue;
      }
      final id = (j['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final geom = WkbParser.parse(
        wkb,
        (j['geom_offset'] as num?)?.toInt() ?? 0,
        (j['geom_len'] as num?)?.toInt() ?? 0,
      );
      if (geom == null || geom.lines.isEmpty) {
        warnings.add('Géométrie illisible pour $id');
        continue;
      }
      rows.add(_Row(id: id, json: j, lines: geom.lines));
    }

    final plan = planJson == null ? const <PlanArcEntry>[] : PlanArcEntry.listFromJson(planJson);
    final byId = {for (final r in rows) r.id: r};
    final consumed = <String>{};
    final out = <Itineraire>[];
    for (final entry in plan) {
      final matched = <_Row>[];
      for (final id in entry.datasetIds) {
        final row = byId[id];
        if (row == null) {
          warnings.add('Plan ${entry.numero} : tronçon $id absent du jeu de données');
          continue;
        }
        if (!consumed.add(id)) {
          warnings.add('Plan ${entry.numero} : tronçon $id déjà utilisé par un autre itinéraire');
          continue;
        }
        matched.add(row);
      }
      if (matched.isEmpty) continue;
      out.add(_planItineraire(entry, matched));
    }
    final listed = out.length;
    for (final row in rows) {
      if (consumed.contains(row.id)) continue;
      out.add(_rowItineraire(row, secondaire: planJson != null));
    }

    final bounds = out.map((e) => e.bounds).fold<GeoBounds?>(null, (a, b) => a == null ? b : a.extend(b));
    final source = RandoSource(
      id: sourceId,
      name: sourceName,
      producteur: 'Agglomération de la Région de Compiègne',
      featureType: (meta?['dataset'] as Map?)?['layer_name']?.toString() ?? 'itinerairecyclable',
      itineraireCount: planJson != null ? listed : out.length,
      enabled: true,
      activite: Activite.velo,
      bounds: bounds,
      embedded: true,
    );
    return (source: source, itineraires: out, warnings: warnings);
  }

  /// A numbered itinerary of the plan, drawn with the geometry of [matched].
  static Itineraire _planItineraire(PlanArcEntry entry, List<_Row> matched) {
    final lines = <List<LatLng>>[for (final r in matched) ...r.lines];
    final tracks = mergeSegments(dedupeLines(lines));
    final bounds = GeoBounds.fromPoints(tracks.expand((l) => l))!;
    final first = matched.first;
    final etapes = entry.etapes;
    final loop = tracks.length == 1 && haversineM(tracks.first.first, tracks.first.last) < 200;
    return Itineraire(
      id: entry.id,
      sourceId: sourceId,
      sourceName: sourceName,
      nom: entry.nom,
      activite: Activite.velo,
      tracks: tracks,
      start: tracks.first.first,
      bounds: bounds,
      pratique: 'vélo',
      typeItineraire: loop ? 'boucle' : 'linéaire',
      communes: etapes,
      depart: etapes.first,
      arrivee: etapes.last,
      dureeH: entry.longueurKm / speedKmh,
      longueurM: entry.longueurKm * 1000,
      numero: '${entry.numero}',
      statutReseau: StatutReseau.fromCode(first.str('status')),
      niveau: first.str('level'),
      couleur: entry.couleur,
      secondaire: false,
      embedded: true,
    );
  }

  /// One dataset row as a route (legacy behaviour, or a secondary lane).
  static Itineraire _rowItineraire(_Row row, {required bool secondaire}) {
    final j = row.json;
    final tracks = mergeSegments(row.lines);
    final from = row.str('from');
    final to = row.str('to');
    var name = row.str('name') ?? '';
    if (name.isEmpty || name.toLowerCase() == 'sans nom') {
      name = from ?? 'Itinéraire cyclable';
    }
    final lengthM = (j['length_m'] as num?)?.toDouble() ?? tracksLengthM(tracks);
    final startRaw = (j['start_wgs84'] as List?)?.map((e) => (e as num).toDouble()).toList();
    final start = startRaw != null && startRaw.length >= 2 ? LatLng(startRaw[1], startRaw[0]) : tracks.first.first;
    final bounds = GeoBounds.fromPoints(tracks.expand((l) => l))!;
    final gain = (j['elevation_gain_m'] as num?)?.toDouble();
    final loss = (j['elevation_loss_m'] as num?)?.toDouble();
    final communes = <String>[
      ?from,
      if (to != null && to != from) to,
    ];
    return Itineraire(
      id: row.id,
      sourceId: sourceId,
      sourceName: sourceName,
      nom: name,
      activite: Activite.velo,
      tracks: tracks,
      start: start,
      bounds: bounds,
      pratique: 'vélo',
      typeItineraire: (from != null && to != null && from == to) ? 'boucle' : 'linéaire',
      communes: communes,
      depart: from,
      arrivee: to,
      dureeH: lengthM / 1000 / speedKmh,
      longueurM: lengthM,
      denivelePositif: (gain ?? 0) > 0 ? gain : null,
      deniveleNegatif: (loss ?? 0) > 0 ? loss : null,
      altMax: (j['elevation_max_m'] as num?)?.toDouble(),
      altMin: (j['elevation_min_m'] as num?)?.toDouble(),
      // Dataset numbers ("Piste 4", "106") are never shown next to the plan.
      numero: secondaire ? null : row.str('number'),
      statutReseau: StatutReseau.fromCode(row.str('status')),
      niveau: row.str('level'),
      couleur: secondaire ? secondaryCouleur : null,
      secondaire: secondaire,
      embedded: true,
    );
  }

  /// Drops the polylines that merely retrace lines already kept: the dataset
  /// often stores both sides of a lane, or the same lane under two numbers.
  /// A line is dropped when at least [minCoverage] of its length lies within
  /// [toleranceM] of the lines kept before it (order matters: give the main
  /// row first).
  static List<List<LatLng>> dedupeLines(
    List<List<LatLng>> lines, {
    double toleranceM = 15,
    double minCoverage = 0.8,
  }) {
    final kept = <List<LatLng>>[];
    final segs = <_Seg>[];
    double? cosLat;
    for (final line in lines) {
      if (line.length < 2) continue;
      cosLat ??= math.cos(line.first.latitude * math.pi / 180);
      _XY xy(LatLng p) => _XY(p.longitude * _mPerDeg * cosLat!, p.latitude * _mPerDeg);
      if (segs.isNotEmpty) {
        var total = 0, near = 0;
        for (var i = 1; i < line.length; i++) {
          final a = xy(line[i - 1]), b = xy(line[i]);
          final d = a.distanceTo(b);
          final n = math.max(1, (d / 20).ceil());
          for (var k = 0; k <= n; k++) {
            if (k == n && i < line.length - 1) break; // shared with the next segment
            final p = _XY(a.x + (b.x - a.x) * k / n, a.y + (b.y - a.y) * k / n);
            total++;
            if (segs.any((s) => s.distanceTo(p) < toleranceM)) near++;
          }
        }
        if (total > 0 && near / total >= minCoverage) continue;
      }
      kept.add(line);
      for (var i = 1; i < line.length; i++) {
        segs.add(_Seg(xy(line[i - 1]), xy(line[i])));
      }
    }
    return kept;
  }

  static const double _mPerDeg = 111320;
}

class _Row {
  const _Row({required this.id, required this.json, required this.lines});

  final String id;
  final Map<String, dynamic> json;
  final List<List<LatLng>> lines;

  String? str(String key) {
    final v = json[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// A point in local metres (equirectangular projection).
class _XY {
  const _XY(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(_XY o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
}

class _Seg {
  const _Seg(this.a, this.b);
  final _XY a;
  final _XY b;

  double distanceTo(_XY p) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    var t = len2 > 0 ? ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2 : 0.0;
    t = t.clamp(0.0, 1.0);
    final cx = a.x + t * dx, cy = a.y + t * dy;
    return math.sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
  }
}
