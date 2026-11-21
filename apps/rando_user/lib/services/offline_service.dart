import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:rando_core/rando_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_style.dart';

/// Offline map areas, one per saved route, backed by MapLibre's offline
/// region database. Route data itself is kept by Firestore persistence
/// (hikes) or shipped with the app (cycling network).
class OfflineService extends ChangeNotifier {
  OfflineService._(this._prefs, this._styleId, this._regions);

  static const _regionsKey = 'offline_regions'; // routeId -> region id
  static const _styleKey = 'map_style';
  static const double minZoom = 12;
  static const double maxZoom = 16;

  final SharedPreferences _prefs;
  String _styleId;
  final Map<String, int> _regions;

  /// Progress per route currently downloading (0..1).
  final Map<String, double> progress = {};

  static Future<OfflineService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final regions = <String, int>{};
    final raw = prefs.getString(_regionsKey);
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map).forEach((k, v) => regions['$k'] = (v as num).toInt());
      } catch (_) {}
    }
    final svc = OfflineService._(prefs, prefs.getString(_styleKey) ?? MapStyle.osm.id, regions);
    if (supported) svc._reconcile();
    return svc;
  }

  /// Offline regions are a native feature (Android / iOS).
  static bool get supported => !kIsWeb;

  MapStyle get style => MapStyle.byId(_styleId);

  Future<void> setStyle(MapStyle s) async {
    _styleId = s.id;
    await _prefs.setString(_styleKey, s.id);
    notifyListeners();
  }

  bool isSaved(String routeId) => _regions.containsKey(routeId);
  bool isDownloading(String routeId) => progress.containsKey(routeId);
  int get savedCount => _regions.length;

  static GeoBounds areaOf(Itineraire it) => it.bounds.pad(400);

  /// Drops references to regions that no longer exist in the database.
  Future<void> _reconcile() async {
    try {
      final existing = await getListOfRegions();
      final ids = existing.map((r) => r.id).toSet();
      _regions.removeWhere((_, id) => !ids.contains(id));
      await _persist();
    } catch (_) {}
  }

  /// Downloads the map tiles around [it] (zooms 12–16). First tries the style
  /// bundled as an asset; if the native side rejects that URL, retries once
  /// with the inline style JSON.
  Future<OfflineSaveResult> save(Itineraire it) async {
    if (!supported) {
      return const OfflineSaveResult(error: 'Le hors-ligne n’est pas disponible sur cette plateforme.');
    }
    if (isDownloading(it.id)) return const OfflineSaveResult();
    progress[it.id] = 0;
    notifyListeners();
    try {
      try {
        return await _download(it, style.offlineStyleUrl, inline: false);
      } catch (_) {
        // Asset style URL rejected: retry once with the style document itself.
        progress[it.id] = 0;
        notifyListeners();
        return await _download(it, style.styleJson(), inline: true);
      }
    } catch (e) {
      return OfflineSaveResult(error: e.toString());
    } finally {
      progress.remove(it.id);
      notifyListeners();
    }
  }

  Future<OfflineSaveResult> _download(Itineraire it, String styleUrl, {required bool inline}) async {
    String? error;
    final b = areaOf(it);
    final region = await downloadOfflineRegion(
      OfflineRegionDefinition(
        bounds: LatLngBounds(
          southwest: LatLng(b.minLat, b.minLng),
          northeast: LatLng(b.maxLat, b.maxLng),
        ),
        mapStyleUrl: styleUrl,
        minZoom: minZoom,
        maxZoom: maxZoom,
      ),
      metadata: {'routeId': it.id, 'nom': it.titre, 'style': style.id},
      onEvent: (event) {
        if (event is InProgress) {
          progress[it.id] = (event.progress / 100).clamp(0.0, 1.0);
          notifyListeners();
        } else if (event is Error) {
          error = event.cause.message ?? 'Erreur de téléchargement';
        }
      },
    );
    // Replace any previous region for this route.
    final old = _regions[it.id];
    if (old != null && old != region.id) {
      try {
        await deleteOfflineRegion(old);
      } catch (_) {}
    }
    _regions[it.id] = region.id;
    await _persist();
    return OfflineSaveResult(error: error, usedInlineStyle: inline);
  }

  Future<void> forget(String routeId) async {
    final id = _regions.remove(routeId);
    if (id != null && supported) {
      try {
        await deleteOfflineRegion(id);
      } catch (_) {}
    }
    await _persist();
  }

  Future<void> clearAll() async {
    if (supported) {
      for (final id in _regions.values) {
        try {
          await deleteOfflineRegion(id);
        } catch (_) {}
      }
    }
    _regions.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_regionsKey, jsonEncode(_regions));
    notifyListeners();
  }
}

/// Outcome of [OfflineService.save].
class OfflineSaveResult {
  const OfflineSaveResult({this.error, this.usedInlineStyle = false});

  /// Null on success.
  final String? error;

  /// True when the asset style URL was rejected and the inline JSON worked.
  final bool usedInlineStyle;

  bool get ok => error == null;

  /// Snackbar text, mentioning which style source worked.
  String get message {
    if (error != null) return 'Téléchargement impossible : $error';
    return usedInlineStyle
        ? 'Carte enregistrée (style intégré) : ce circuit est utilisable sans réseau.'
        : 'Carte enregistrée : ce circuit est utilisable sans réseau.';
  }
}
