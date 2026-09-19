import 'package:flutter/foundation.dart';
import 'package:rando_core/rando_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tile_cache.dart';

/// Tracks which routes were downloaded for offline use and drives the tile
/// prefetch. Route data itself is kept by Firestore's local persistence.
class OfflineService extends ChangeNotifier {
  OfflineService._(this._prefs, this.tiles, this._downloaded, this._styleId);

  static const _key = 'offline_routes';
  static const _styleKey = 'map_style';
  static const zooms = [12, 13, 14, 15, 16];

  final SharedPreferences _prefs;
  final TileCache tiles;
  final Set<String> _downloaded;
  String _styleId;

  /// Progress per route currently downloading (0..1).
  final Map<String, double> progress = {};
  final Set<String> _cancel = {};

  static Future<OfflineService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await TileCache.create();
    return OfflineService._(
      prefs,
      cache,
      (prefs.getStringList(_key) ?? []).toSet(),
      prefs.getString(_styleKey) ?? MapStyle.ign.id,
    );
  }

  MapStyle get style => MapStyle.byId(_styleId);

  Future<void> setStyle(MapStyle s) async {
    _styleId = s.id;
    await _prefs.setString(_styleKey, s.id);
    notifyListeners();
  }

  bool isDownloaded(String id) => _downloaded.contains(id);
  bool isDownloading(String id) => progress.containsKey(id);
  int get downloadedCount => _downloaded.length;

  static GeoBounds areaOf(Itineraire it) => it.bounds.pad(400);

  int tileCount(Itineraire it) => TileCache.tilesFor(areaOf(it), zooms).length;

  Future<bool> download(Itineraire it) async {
    if (isDownloading(it.id)) return false;
    progress[it.id] = 0;
    _cancel.remove(it.id);
    notifyListeners();
    final failed = await tiles.prefetch(
      style,
      areaOf(it),
      zooms: zooms,
      onProgress: (done, total) {
        progress[it.id] = total == 0 ? 1 : done / total;
        notifyListeners();
      },
      isCancelled: () => _cancel.contains(it.id),
    );
    progress.remove(it.id);
    final cancelled = _cancel.remove(it.id);
    final ok = !cancelled && failed == 0;
    if (ok) {
      _downloaded.add(it.id);
      await _prefs.setStringList(_key, _downloaded.toList());
    }
    notifyListeners();
    return ok;
  }

  void cancel(String id) => _cancel.add(id);

  Future<void> forget(String id) async {
    _downloaded.remove(id);
    await _prefs.setStringList(_key, _downloaded.toList());
    notifyListeners();
  }

  Future<void> clearAll() async {
    await tiles.clear();
    _downloaded.clear();
    await _prefs.setStringList(_key, const []);
    notifyListeners();
  }
}
