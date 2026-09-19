import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:rando_core/rando_core.dart';

import 'main.dart' show ensureSignedIn;
import 'services/favorites_service.dart';
import 'services/location_service.dart';
import 'services/offline_service.dart';

/// How the "origin" used to sort routes is chosen.
enum OriginMode { gps, manual, none }

/// Global app state: Firestore streams, favorites, origin, GPS position.
class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.favorites,
    required this.offline,
  });

  final RandoRepository repository;
  final FavoritesService favorites;
  final OfflineService offline;
  final LocationService location = LocationService();

  String? uid;
  List<RandoSource> sources = const [];
  List<Itineraire> _itineraires = const [];
  List<Signalement> signalements = const [];
  List<ElementRemarquable> elements = const [];
  bool itinerairesLoaded = false;
  bool itinerairesFromCache = false;
  String? loadError;

  OriginMode originMode = OriginMode.gps;
  LatLng? manualOrigin;
  LatLng? gpsPosition;
  bool showSignalementsOnMap = true;
  bool showElementsOnMap = true;
  String? sourceFilter;
  String search = '';

  final _subs = <StreamSubscription>[];

  /// Routes of enabled sources, alphabetically sorted.
  List<Itineraire> get itineraires {
    final enabled = sources.where((s) => s.enabled).map((s) => s.id).toSet();
    return _itineraires
        .where((it) => sources.isEmpty || enabled.contains(it.sourceId))
        .toList();
  }

  LatLng? get origin {
    switch (originMode) {
      case OriginMode.gps:
        return gpsPosition;
      case OriginMode.manual:
        return manualOrigin;
      case OriginMode.none:
        return null;
    }
  }

  /// Routes filtered by search / source and sorted by distance from origin
  /// when one is known, otherwise by name.
  List<Itineraire> get visibleItineraires {
    final q = search.trim().toLowerCase();
    var list = itineraires.where((it) {
      if (sourceFilter != null && it.sourceId != sourceFilter) return false;
      if (q.isEmpty) return true;
      return it.nom.toLowerCase().contains(q) ||
          it.communesLabel.toLowerCase().contains(q) ||
          (it.depart ?? '').toLowerCase().contains(q);
    }).toList();
    final o = origin;
    if (o != null) {
      list.sort((a, b) =>
          haversineM(o, a.start).compareTo(haversineM(o, b.start)));
    } else {
      list.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    }
    return list;
  }

  double? distanceFromOrigin(Itineraire it) {
    final o = origin;
    return o == null ? null : haversineM(o, it.start);
  }

  List<Itineraire> get favoriteItineraires =>
      itineraires.where((it) => favorites.contains(it.id)).toList();

  Itineraire? itineraireById(String id) {
    for (final it in _itineraires) {
      if (it.id == id) return it;
    }
    return null;
  }

  List<Signalement> signalementsFor(String itineraireId) =>
      signalements.where((s) => s.itineraireId == itineraireId).toList();

  /// Validated points of interest plus the ones proposed by this device.
  List<ElementRemarquable> elementsFor(String itineraireId,
      {bool includeMine = true}) =>
      elements
          .where((e) =>
              e.itineraireId == itineraireId &&
              (e.isValide || (includeMine && e.isAuthor(uid))))
          .toList();

  List<ElementRemarquable> get validatedElements =>
      elements.where((e) => e.isValide).toList();

  void start() {
    _subs.add(repository.sources.snapshots().listen((snap) {
      sources = snap.docs
          .map((d) => RandoSource.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }, onError: (e) => _error(e)));

    _subs.add(repository.itineraires
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      _itineraires = snap.docs
          .map((d) => Itineraire.fromMap(d.id, d.data()))
          .toList();
      itinerairesLoaded = true;
      itinerairesFromCache = snap.metadata.isFromCache;
      loadError = null;
      notifyListeners();
    }, onError: (e) => _error(e)));

    _subs.add(repository.watchSignalements().listen((list) {
      signalements = list;
      notifyListeners();
    }, onError: (e) => _error(e)));

    _subs.add(repository.watchElements().listen((list) {
      elements = list;
      notifyListeners();
    }, onError: (e) => _error(e)));

    _subs.add(FirebaseAuth.instance.authStateChanges().listen((u) {
      uid = u?.uid;
      notifyListeners();
    }));
    ensureSignedIn();
    refreshGps();
  }

  void _error(Object e) {
    loadError = e.toString();
    notifyListeners();
  }

  Future<void> refreshGps() async {
    final p = await location.currentPosition();
    if (p != null) {
      gpsPosition = p;
      notifyListeners();
    }
  }

  void setOriginMode(OriginMode mode) {
    originMode = mode;
    if (mode == OriginMode.gps) refreshGps();
    notifyListeners();
  }

  void setManualOrigin(LatLng p) {
    manualOrigin = p;
    originMode = OriginMode.manual;
    notifyListeners();
  }

  void setSearch(String q) {
    search = q;
    notifyListeners();
  }

  void setSourceFilter(String? id) {
    sourceFilter = id;
    notifyListeners();
  }

  void toggleShowSignalements() {
    showSignalementsOnMap = !showSignalementsOnMap;
    notifyListeners();
  }

  void toggleShowElements() {
    showElementsOnMap = !showElementsOnMap;
    notifyListeners();
  }

  bool isFavorite(String id) => favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    await favorites.toggle(id);
    notifyListeners();
  }

  /// Returns null when the device could not be authenticated yet (first
  /// launch without network).
  Future<String?> requireUid() async {
    uid ??= await ensureSignedIn();
    return uid;
  }

  Future<bool> vote(Signalement s) async {
    final u = await requireUid();
    if (u == null || s.hasVoted(u)) return false;
    // Optimistic local update; Firestore will confirm through the stream.
    signalements = signalements
        .map((x) => x.id == s.id
            ? Signalement(
                id: x.id,
                itineraireId: x.itineraireId,
                itineraireNom: x.itineraireNom,
                sourceId: x.sourceId,
                categorie: x.categorie,
                description: x.description,
                position: x.position,
                statut: x.statut,
                auteurId: x.auteurId,
                votes: x.votes + 1,
                voters: [...x.voters, u],
                createdAt: x.createdAt,
                updatedAt: x.updatedAt,
                validePar: x.validePar,
                valideAt: x.valideAt,
                commentaireAdmin: x.commentaireAdmin,
              )
            : x)
        .toList();
    notifyListeners();
    repository.voteSignalement(s.id, u);
    return true;
  }

  Future<bool> createSignalement({
    required Itineraire itineraire,
    required SignalementCategorie categorie,
    required String description,
    required LatLng position,
  }) async {
    final u = await requireUid();
    if (u == null) return false;
    await repository.createSignalement(Signalement(
      id: '',
      itineraireId: itineraire.id,
      itineraireNom: itineraire.nom,
      sourceId: itineraire.sourceId,
      categorie: categorie,
      description: description,
      position: position,
      statut: SignalementStatut.signale,
      auteurId: u,
      votes: 1,
      voters: [u],
    ));
    return true;
  }

  Future<bool> createElement({
    required Itineraire itineraire,
    required ElementCategorie categorie,
    required String titre,
    required String description,
    required LatLng position,
  }) async {
    final u = await requireUid();
    if (u == null) return false;
    await repository.createElement(ElementRemarquable(
      id: '',
      itineraireId: itineraire.id,
      itineraireNom: itineraire.nom,
      sourceId: itineraire.sourceId,
      categorie: categorie,
      titre: titre,
      description: description,
      position: position,
      statut: ElementStatut.enAttente,
      auteurId: u,
    ));
    return true;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
