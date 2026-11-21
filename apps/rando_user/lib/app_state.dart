import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:rando_core/rando_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show signInDetailed;
import 'services/favorites_service.dart';
import 'services/location_service.dart';
import 'services/offline_service.dart';
import 'services/ride_controller.dart';
import 'services/sorties_service.dart';
import 'services/weather_service.dart';

/// How the "origin" used to sort routes is chosen.
enum OriginMode { gps, manual, none }

/// Global app state: Firestore streams, the embedded cycling dataset,
/// favorites, origin, GPS position, appearance preferences.
class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.favorites,
    required this.offline,
    required this.prefs,
    required this.weather,
    required this.sorties,
    required this.ride,
    required this.veloSource,
    required List<Itineraire> veloItineraires,
  })  : _velo = veloItineraires,
        _themeMode = _themeFromString(prefs.getString(_kTheme)),
        _displayName = prefs.getString(_kName) ?? '';

  static const _kTheme = 'theme_mode';
  static const _kName = 'display_name';

  final RandoRepository repository;
  final FavoritesService favorites;
  final OfflineService offline;
  final SharedPreferences prefs;
  final WeatherService weather;
  final SortiesService sorties;
  final RideController ride;
  final LocationService location = LocationService();

  /// Cycling network bundled with the app (always on the phone).
  final RandoSource veloSource;
  final List<Itineraire> _velo;

  String? uid;

  /// User-facing reason why the device is not signed in (null when it is, or
  /// when no attempt failed yet).
  String? authError;
  List<RandoSource> _firestoreSources = const [];
  List<Itineraire> _firestoreItineraires = const [];
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
  Activite? activiteFilter;
  String search = '';

  ThemeMode _themeMode;
  String _displayName;
  String? _discoveryId;
  final _random = math.Random();

  final _subs = <StreamSubscription>[];

  // ------------------------------------------------------------ appearance

  ThemeMode get themeMode => _themeMode;
  String get displayName => _displayName;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await prefs.setString(_kTheme, mode.name);
    notifyListeners();
  }

  /// Switches between light and dark from the currently displayed brightness.
  Future<void> toggleTheme(Brightness current) =>
      setThemeMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setDisplayName(String name) async {
    _displayName = name.trim();
    await prefs.setString(_kName, _displayName);
    notifyListeners();
  }

  static ThemeMode _themeFromString(String? s) =>
      ThemeMode.values.firstWhere((m) => m.name == s, orElse: () => ThemeMode.system);

  // --------------------------------------------------------------- sources

  /// Every source: the embedded cycling network first, then Firestore ones
  /// (a Firestore mirror of the cycling network is hidden on the phone).
  List<RandoSource> get sources => [
        veloSource,
        ..._firestoreSources.where((s) => s.id != veloSource.id),
      ];

  bool _sourceEnabled(String id) {
    if (id == veloSource.id) return true;
    for (final s in _firestoreSources) {
      if (s.id == id) return s.enabled;
    }
    return _firestoreSources.isEmpty;
  }

  /// Routes of enabled sources: embedded cycling routes plus Firestore
  /// hikes (Firestore copies of embedded routes are ignored).
  List<Itineraire> get itineraires {
    final embeddedIds = _velo.map((e) => e.id).toSet();
    return [
      ..._velo.where((it) => !it.secondaire),
      ..._firestoreItineraires.where(
        (it) => it.sourceId != veloSource.id && !embeddedIds.contains(it.id) && _sourceEnabled(it.sourceId),
      ),
    ];
  }

  /// Cycling segments outside the numbered plan itineraries (drawn thin on
  /// maps, never listed).
  List<Itineraire> get veloSecondaires => _velo.where((it) => it.secondaire).toList();

  int countFor(Activite a) => itineraires.where((it) => it.activite == a).length;

  // ----------------------------------------------------------- itineraires

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

  String get originLabel => switch (originMode) {
        OriginMode.gps => gpsPosition == null ? 'Position inconnue' : 'Depuis ma position',
        OriginMode.manual => manualOrigin == null ? 'Choisir sur la carte' : 'Depuis le point choisi',
        OriginMode.none => 'Tri par nom',
      };

  List<Itineraire> _sorted(Iterable<Itineraire> input) {
    final list = input.toList();
    final o = origin;
    if (o != null) {
      list.sort((a, b) => haversineM(o, a.start).compareTo(haversineM(o, b.start)));
    } else {
      list.sort((a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()));
    }
    return list;
  }

  /// Routes matching the activity filter, sorted by distance from origin
  /// (or by name).
  List<Itineraire> get sortedItineraires =>
      _sorted(itineraires.where((it) => activiteFilter == null || it.activite == activiteFilter));

  /// Routes filtered by search / source / activity and sorted like
  /// [sortedItineraires].
  List<Itineraire> get visibleItineraires {
    final q = search.trim().toLowerCase();
    return sortedItineraires.where((it) {
      if (sourceFilter != null && it.sourceId != sourceFilter) return false;
      if (q.isEmpty) return true;
      return it.titre.toLowerCase().contains(q) ||
          it.communesLabel.toLowerCase().contains(q) ||
          (it.depart ?? '').toLowerCase().contains(q) ||
          (it.arrivee ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<Itineraire> nearest({int limit = 5}) => sortedItineraires.take(limit).toList();

  /// Random route put forward on the home screen (hike or ride). Stable
  /// until [shuffleDiscovery] is called or the route disappears.
  Itineraire? get discovery {
    final all = itineraires;
    if (all.isEmpty) return null;
    final current = _discoveryId == null ? null : itineraireById(_discoveryId!);
    if (current != null) return current;
    final pick = all[_random.nextInt(all.length)];
    _discoveryId = pick.id;
    return pick;
  }

  void shuffleDiscovery() {
    final all = itineraires;
    if (all.length <= 1) return;
    // Alternate activities when possible so both worlds get discovered.
    final currentActivite = _discoveryId == null ? null : itineraireById(_discoveryId!)?.activite;
    final other = currentActivite == null
        ? all
        : all.where((it) => it.activite != currentActivite).toList();
    final pool = (other.isNotEmpty ? other : all).where((it) => it.id != _discoveryId).toList();
    final candidates = pool.isEmpty ? all : pool;
    _discoveryId = candidates[_random.nextInt(candidates.length)].id;
    notifyListeners();
  }

  double? distanceFromOrigin(Itineraire it) {
    final o = origin;
    return o == null ? null : haversineM(o, it.start);
  }

  List<Itineraire> get favoriteItineraires => itineraires.where((it) => favorites.contains(it.id)).toList();

  Itineraire? itineraireById(String id) {
    for (final it in _velo) {
      if (it.id == id) return it;
    }
    for (final it in _firestoreItineraires) {
      if (it.id == id) return it;
    }
    return null;
  }

  List<Signalement> signalementsFor(String itineraireId) =>
      signalements.where((s) => s.itineraireId == itineraireId).toList();

  List<Signalement> recentSignalements({int limit = 3}) => signalements.take(limit).toList();

  /// Validated points of interest plus the ones proposed by this device.
  List<ElementRemarquable> elementsFor(String itineraireId, {bool includeMine = true}) => elements
      .where((e) => e.itineraireId == itineraireId && (e.isValide || (includeMine && e.isAuthor(uid))))
      .toList();

  /// Reports created from this device.
  List<Signalement> get mySignalements => signalements.where((s) => s.isAuthor(uid)).toList();

  /// Points of interest proposed from this device, whatever their statut.
  List<ElementRemarquable> get myElements => elements.where((e) => e.isAuthor(uid)).toList();

  List<ElementRemarquable> get validatedElements => elements.where((e) => e.isValide).toList();

  // --------------------------------------------------------------- streams

  void start() {
    itinerairesLoaded = _velo.isNotEmpty;
    _subs.add(repository.sources.snapshots().listen((snap) {
      _firestoreSources = snap.docs.map((d) => RandoSource.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }, onError: _error));

    _subs.add(repository.itineraires.snapshots(includeMetadataChanges: true).listen((snap) {
      _firestoreItineraires = snap.docs.map((d) => Itineraire.fromMap(d.id, d.data())).toList();
      itinerairesLoaded = true;
      itinerairesFromCache = snap.metadata.isFromCache;
      loadError = null;
      notifyListeners();
    }, onError: _error));

    _subs.add(repository.watchSignalements().listen((list) {
      signalements = list;
      notifyListeners();
    }, onError: _error));

    _subs.add(repository.watchElements().listen((list) {
      elements = list;
      notifyListeners();
    }, onError: _error));

    _subs.add(FirebaseAuth.instance.authStateChanges().listen((u) {
      uid = u?.uid;
      if (u != null) authError = null;
      notifyListeners();
    }));
    requireUid();
    refreshGps();
    weather.refresh();
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

  /// Pull-to-refresh: GPS, weather and a new discovery.
  Future<void> refreshAll() async {
    shuffleDiscovery();
    await Future.wait([refreshGps(), weather.refresh(force: true)]);
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

  void setActiviteFilter(Activite? a) {
    activiteFilter = a;
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

  /// Message for a failed sign-in code. Distinguishes "Firebase Auth is not
  /// enabled on the project" from a real network problem.
  static String authMessageFor(String? code, [String? message]) {
    // On Android the native SDK wraps backend errors such as
    // CONFIGURATION_NOT_FOUND into an "internal-error" whose message
    // carries the real reason.
    final m = (message ?? '').toUpperCase();
    if (m.contains('CONFIGURATION_NOT_FOUND') || m.contains('OPERATION_NOT_ALLOWED')) {
      return 'Le service de signalement n’est pas encore activé.';
    }
    switch (code) {
      case 'configuration-not-found':
      case 'operation-not-allowed':
      case 'admin-restricted-operation':
        return 'Le service de signalement n’est pas encore activé.';
      case 'network-request-failed':
      case 'unknown':
      case null:
        return 'Une première connexion internet est nécessaire pour activer les signalements.';
      default:
        return 'Connexion au service impossible pour le moment ($code).';
    }
  }

  /// Returns null when the device could not be authenticated yet (first
  /// launch without network, or Authentication not enabled); [authError]
  /// then explains why.
  Future<String?> requireUid() async {
    if (uid != null) return uid;
    final r = await signInDetailed();
    if (r.uid != null) {
      uid = r.uid;
      authError = null;
    } else {
      authError = authMessageFor(r.errorCode, r.errorMessage);
    }
    notifyListeners();
    return uid;
  }

  Future<bool> vote(Signalement s) async {
    final u = await requireUid();
    if (u == null || s.hasVoted(u) || s.isAuthor(u)) return false;
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
    repository.voteSignalement(s.id, u).catchError((Object e) {
      debugPrint('Vote refusé : $e');
    });
    return true;
  }

  Future<bool> createSignalement({
    required Itineraire itineraire,
    required SignalementCategorie categorie,
    String description = '',
    required LatLng position,
  }) async {
    final u = await requireUid();
    if (u == null) return false;
    await repository.createSignalement(Signalement(
      id: '',
      itineraireId: itineraire.id,
      itineraireNom: itineraire.titre,
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
    String description = '',
    required LatLng position,
  }) async {
    final u = await requireUid();
    if (u == null) return false;
    await repository.createElement(ElementRemarquable(
      id: '',
      itineraireId: itineraire.id,
      itineraireNom: itineraire.titre,
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
