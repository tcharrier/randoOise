import 'package:shared_preferences/shared_preferences.dart';

/// Favorites live on the device only, so they work offline and need no
/// account.
class FavoritesService {
  FavoritesService._(this._prefs, this._ids);

  static const _key = 'favorites';
  final SharedPreferences _prefs;
  final Set<String> _ids;

  static Future<FavoritesService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return FavoritesService._(prefs, (prefs.getStringList(_key) ?? []).toSet());
  }

  bool contains(String id) => _ids.contains(id);
  Set<String> get ids => Set.unmodifiable(_ids);
  int get length => _ids.length;

  Future<void> toggle(String id) async {
    if (!_ids.remove(id)) _ids.add(id);
    await _prefs.setStringList(_key, _ids.toList());
  }
}
