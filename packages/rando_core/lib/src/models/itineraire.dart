import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../geo/geo.dart';

class MediaItem {
  const MediaItem({this.url, this.titre, this.auteur, this.licence, this.type});
  final String? url;
  final String? titre;
  final String? auteur;
  final String? licence;
  final String? type;

  Map<String, dynamic> toMap() => {
        'url': url,
        'titre': titre,
        'auteur': auteur,
        'licence': licence,
        'type': type,
      };

  static MediaItem? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final item = MediaItem(
      url: m['url'] as String?,
      titre: m['titre'] as String?,
      auteur: m['auteur'] as String?,
      licence: m['licence'] as String?,
      type: (m['type'] ?? m['type_media']) as String?,
    );
    if (item.url == null && item.titre == null) return null;
    return item;
  }
}

/// A hiking route (schéma national "itinéraires de randonnée").
class Itineraire {
  const Itineraire({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.nom,
    required this.tracks,
    required this.start,
    required this.bounds,
    this.pratique,
    this.typeItineraire,
    this.communes = const [],
    this.depart,
    this.arrivee,
    this.dureeH,
    this.balisage,
    this.longueurM,
    this.difficulte,
    this.altMax,
    this.altMin,
    this.denivelePositif,
    this.deniveleNegatif,
    this.instructions,
    this.presentation,
    this.presentationCourte,
    this.themes = const [],
    this.recommandations,
    this.accessibilite,
    this.accesRoutier,
    this.transportsCommun,
    this.parkingInfo,
    this.parking,
    this.dateCreation,
    this.dateModification,
    this.medias = const [],
    this.typeSol,
    this.pdipr = false,
    this.url,
  });

  final String id;
  final String sourceId;
  final String sourceName;
  final String nom;
  final List<List<LatLng>> tracks;
  final LatLng start;
  final GeoBounds bounds;
  final String? pratique;
  final String? typeItineraire;
  final List<String> communes;
  final String? depart;
  final String? arrivee;
  final double? dureeH;
  final String? balisage;
  final double? longueurM;
  final String? difficulte;
  final double? altMax;
  final double? altMin;
  final double? denivelePositif;
  final double? deniveleNegatif;
  final String? instructions;
  final String? presentation;
  final String? presentationCourte;
  final List<String> themes;
  final String? recommandations;
  final String? accessibilite;
  final String? accesRoutier;
  final String? transportsCommun;
  final String? parkingInfo;
  final LatLng? parking;
  final String? dateCreation;
  final String? dateModification;
  final List<MediaItem> medias;
  final String? typeSol;
  final bool pdipr;
  final String? url;

  /// Length in meters, from the data or computed from the track.
  double get lengthM => longueurM ?? tracksLengthM(tracks);

  LatLng get end => tracks.isEmpty ? start : tracks.last.last;

  String get communesLabel => communes.join(', ');

  int get pointCount => tracks.fold(0, (n, l) => n + l.length);

  Map<String, dynamic> toMap() => {
        'sourceId': sourceId,
        'sourceName': sourceName,
        'nom': nom,
        'nomLower': nom.toLowerCase(),
        'tracks': TrackCodec.encode(tracks),
        'start': GeoPoint(start.latitude, start.longitude),
        'bounds': bounds.toMap(),
        'pratique': pratique,
        'typeItineraire': typeItineraire,
        'communes': communes,
        'depart': depart,
        'arrivee': arrivee,
        'dureeH': dureeH,
        'balisage': balisage,
        'longueurM': longueurM,
        'difficulte': difficulte,
        'altMax': altMax,
        'altMin': altMin,
        'denivelePositif': denivelePositif,
        'deniveleNegatif': deniveleNegatif,
        'instructions': instructions,
        'presentation': presentation,
        'presentationCourte': presentationCourte,
        'themes': themes,
        'recommandations': recommandations,
        'accessibilite': accessibilite,
        'accesRoutier': accesRoutier,
        'transportsCommun': transportsCommun,
        'parkingInfo': parkingInfo,
        'parking': parking == null
            ? null
            : GeoPoint(parking!.latitude, parking!.longitude),
        'dateCreation': dateCreation,
        'dateModification': dateModification,
        'medias': medias.map((m) => m.toMap()).toList(),
        'typeSol': typeSol,
        'pdipr': pdipr,
        'url': url,
        'pointCount': pointCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Itineraire.fromMap(String id, Map<String, dynamic> m) {
    final tracks = TrackCodec.decode(m['tracks'] as List?);
    final startGp = m['start'] as GeoPoint?;
    final start = startGp != null
        ? LatLng(startGp.latitude, startGp.longitude)
        : (tracks.isNotEmpty ? tracks.first.first : const LatLng(49.4, 2.8));
    final parkingGp = m['parking'] as GeoPoint?;
    final bounds = GeoBounds.fromMap(
            (m['bounds'] as Map?)?.cast<String, dynamic>()) ??
        GeoBounds.fromPoints(tracks.expand((l) => l)) ??
        GeoBounds(
            minLat: start.latitude,
            minLng: start.longitude,
            maxLat: start.latitude,
            maxLng: start.longitude);
    return Itineraire(
      id: id,
      sourceId: (m['sourceId'] ?? '') as String,
      sourceName: (m['sourceName'] ?? '') as String,
      nom: (m['nom'] ?? 'Itinéraire') as String,
      tracks: tracks,
      start: start,
      bounds: bounds,
      pratique: m['pratique'] as String?,
      typeItineraire: m['typeItineraire'] as String?,
      communes: _strList(m['communes']),
      depart: m['depart'] as String?,
      arrivee: m['arrivee'] as String?,
      dureeH: (m['dureeH'] as num?)?.toDouble(),
      balisage: m['balisage'] as String?,
      longueurM: (m['longueurM'] as num?)?.toDouble(),
      difficulte: m['difficulte'] as String?,
      altMax: (m['altMax'] as num?)?.toDouble(),
      altMin: (m['altMin'] as num?)?.toDouble(),
      denivelePositif: (m['denivelePositif'] as num?)?.toDouble(),
      deniveleNegatif: (m['deniveleNegatif'] as num?)?.toDouble(),
      instructions: m['instructions'] as String?,
      presentation: m['presentation'] as String?,
      presentationCourte: m['presentationCourte'] as String?,
      themes: _strList(m['themes']),
      recommandations: m['recommandations'] as String?,
      accessibilite: m['accessibilite'] as String?,
      accesRoutier: m['accesRoutier'] as String?,
      transportsCommun: m['transportsCommun'] as String?,
      parkingInfo: m['parkingInfo'] as String?,
      parking: parkingGp == null
          ? null
          : LatLng(parkingGp.latitude, parkingGp.longitude),
      dateCreation: m['dateCreation'] as String?,
      dateModification: m['dateModification'] as String?,
      medias: ((m['medias'] as List?) ?? const [])
          .map((e) => MediaItem.fromMap((e as Map?)?.cast<String, dynamic>()))
          .whereType<MediaItem>()
          .toList(),
      typeSol: m['typeSol'] as String?,
      pdipr: (m['pdipr'] as bool?) ?? false,
      url: m['url'] as String?,
    );
  }

  static List<String> _strList(dynamic v) =>
      ((v as List?) ?? const []).map((e) => e.toString()).toList();
}
