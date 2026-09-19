import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rando_core/rando_core.dart';

/// Available base maps. IGN "Plan" is free of charge and key-less on the
/// Géoplateforme, and better suited to French trails than OSM.
class MapStyle {
  const MapStyle({required this.id, required this.label, required this.urlTemplate, required this.attribution, this.maxZoom = 19});
  final String id;
  final String label;
  final String urlTemplate;
  final String attribution;
  final int maxZoom;

  static const ign = MapStyle(
    id: 'ign',
    label: 'Plan IGN',
    urlTemplate:
        'https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&STYLE=normal&FORMAT=image/png&TILEMATRIXSET=PM&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}',
    attribution: '© IGN – Géoplateforme',
  );
  static const osm = MapStyle(
    id: 'osm',
    label: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
  );
  static const all = [ign, osm];
  static MapStyle byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => ign);
}

const String kUserAgent = 'RandoOise/1.0 (fr.randooise.rando_user)';

/// Disk cache for map tiles: every tile displayed is kept on disk, and
/// [prefetch] can download a whole area for offline use.
class TileCache {
  TileCache._(this.root);

  final Directory? root;
  static final http.Client _client = http.Client();

  static Future<TileCache> create() async {
    if (kIsWeb) return TileCache._(null);
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}tiles');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return TileCache._(dir);
  }

  File? fileFor(String styleId, int z, int x, int y) {
    final r = root;
    if (r == null) return null;
    final sep = Platform.pathSeparator;
    return File('${r.path}$sep$styleId$sep$z$sep$x$sep$y.png');
  }

  static String urlFor(MapStyle style, int z, int x, int y) => style.urlTemplate
      .replaceAll('{z}', '$z')
      .replaceAll('{x}', '$x')
      .replaceAll('{y}', '$y');

  /// Returns tile bytes from disk, or downloads (and stores) them.
  Future<Uint8List> load(MapStyle style, int z, int x, int y) async {
    final f = fileFor(style.id, z, x, y);
    if (f != null && f.existsSync()) {
      try {
        final bytes = await f.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {}
    }
    final res = await _client.get(Uri.parse(urlFor(style, z, x, y)),
        headers: const {'User-Agent': kUserAgent});
    if (res.statusCode != 200) {
      throw HttpException('Tuile indisponible (${res.statusCode})');
    }
    if (f != null) {
      try {
        f.parent.createSync(recursive: true);
        await f.writeAsBytes(res.bodyBytes, flush: true);
      } catch (_) {}
    }
    return res.bodyBytes;
  }

  bool has(MapStyle style, int z, int x, int y) =>
      fileFor(style.id, z, x, y)?.existsSync() ?? false;

  /// Tile coordinates covering [bounds] for each zoom in [zooms].
  static List<(int, int, int)> tilesFor(GeoBounds bounds, List<int> zooms) {
    final out = <(int, int, int)>[];
    for (final z in zooms) {
      final (x1, y1) = _tileXY(bounds.maxLat, bounds.minLng, z);
      final (x2, y2) = _tileXY(bounds.minLat, bounds.maxLng, z);
      for (var x = math.min(x1, x2); x <= math.max(x1, x2); x++) {
        for (var y = math.min(y1, y2); y <= math.max(y1, y2); y++) {
          out.add((z, x, y));
        }
      }
    }
    return out;
  }

  static (int, int) _tileXY(double lat, double lng, int z) {
    final n = math.pow(2, z).toDouble();
    final x = ((lng + 180) / 360 * n).floor();
    final latRad = lat * math.pi / 180;
    final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n).floor();
    return (x.clamp(0, n.toInt() - 1), y.clamp(0, n.toInt() - 1));
  }

  /// Downloads all tiles of [bounds] for [zooms]. Reports progress and
  /// returns the number of failures.
  Future<int> prefetch(
    MapStyle style,
    GeoBounds bounds, {
    List<int> zooms = const [12, 13, 14, 15, 16],
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final tiles = tilesFor(bounds, zooms);
    var done = 0;
    var failed = 0;
    const concurrency = 4;
    for (var i = 0; i < tiles.length; i += concurrency) {
      if (isCancelled?.call() ?? false) break;
      final chunk = tiles.skip(i).take(concurrency);
      await Future.wait(chunk.map((t) async {
        try {
          await load(style, t.$1, t.$2, t.$3);
        } catch (_) {
          failed++;
        }
        done++;
        onProgress?.call(done, tiles.length);
      }));
    }
    return failed;
  }

  int cachedCount(MapStyle style, GeoBounds bounds, List<int> zooms) =>
      tilesFor(bounds, zooms).where((t) => has(style, t.$1, t.$2, t.$3)).length;

  Future<int> sizeBytes() async {
    final r = root;
    if (r == null || !r.existsSync()) return 0;
    var total = 0;
    await for (final e in r.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> clear() async {
    final r = root;
    if (r != null && r.existsSync()) {
      await r.delete(recursive: true);
      r.createSync(recursive: true);
    }
  }
}

/// flutter_map tile provider backed by [TileCache].
class CachedTileProvider extends TileProvider {
  CachedTileProvider(this.cache, this.style);

  final TileCache cache;
  final MapStyle style;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _CachedTileImage(cache, style, coordinates.z, coordinates.x, coordinates.y);
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage(this.cache, this.style, this.z, this.x, this.y);

  final TileCache cache;
  final MapStyle style;
  final int z, x, y;

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_CachedTileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: 1,
        debugLabel: 'tile $z/$x/$y',
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await cache.load(style, z, x, y);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage &&
      other.style.id == style.id &&
      other.z == z &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(style.id, z, x, y);
}

/// Helper to build the base layer used by every map in the app.
TileLayer buildTileLayer(TileCache cache, MapStyle style) => TileLayer(
      urlTemplate: style.urlTemplate,
      userAgentPackageName: 'fr.randooise.rando_user',
      tileProvider: kIsWeb ? NetworkTileProvider() : CachedTileProvider(cache, style),
      maxNativeZoom: style.maxZoom,
      keepBuffer: 4,
    );

/// Utility to convert [GeoBounds] to a flutter_map [LatLngBounds].
LatLngBounds toLatLngBounds(GeoBounds b) =>
    LatLngBounds(LatLng(b.minLat, b.minLng), LatLng(b.maxLat, b.maxLng));
