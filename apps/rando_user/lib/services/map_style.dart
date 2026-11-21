import 'dart:convert';

/// Base maps rendered by MapLibre GL as raster tile sources. The style JSON is
/// generated at runtime (works offline and on the web); the matching asset
/// files under assets/styles are used for offline region downloads, which
/// need a style URL.
class MapStyle {
  const MapStyle({
    required this.id,
    required this.label,
    required this.attribution,
    required this.tileUrl,
    required this.assetPath,
    this.maxZoom = 19,
  });

  final String id;
  final String label;
  final String attribution;
  final String tileUrl;
  final String assetPath;
  final int maxZoom;

  static const osm = MapStyle(
    id: 'osm',
    label: 'OpenStreetMap',
    attribution: '© OpenStreetMap contributors',
    tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    assetPath: 'assets/styles/osm.json',
  );

  /// IGN "Plan" from the Géoplateforme: free, key-less, better for trails.
  static const ign = MapStyle(
    id: 'ign',
    label: 'Plan IGN',
    attribution: '© IGN – Géoplateforme',
    tileUrl:
        'https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&STYLE=normal&FORMAT=image/png&TILEMATRIXSET=PM&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}',
    assetPath: 'assets/styles/ign.json',
  );

  static const all = [osm, ign];

  static MapStyle byId(String? id) => all.firstWhere((s) => s.id == id, orElse: () => osm);

  /// MapLibre style document. In dark mode the raster layer is dimmed and
  /// desaturated so overlays stay readable.
  String styleJson({bool dark = false}) => jsonEncode({
        'version': 8,
        'name': label,
        // Required by MapLibre style validation as soon as a symbol layer
        // exists (the web plugin always declares a text-field).
        'glyphs': 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
        'sources': {
          id: {
            'type': 'raster',
            'tiles': [tileUrl],
            'tileSize': 256,
            'maxzoom': maxZoom,
            'attribution': attribution,
          },
        },
        'layers': [
          {
            'id': '$id-raster',
            'type': 'raster',
            'source': id,
            'paint': dark
                ? {
                    'raster-brightness-max': 0.72,
                    'raster-brightness-min': 0.05,
                    'raster-saturation': -0.4,
                    'raster-contrast': 0.05,
                  }
                : <String, dynamic>{},
          },
        ],
      });

  /// Style URL understood by the native offline manager (Android assets).
  String get offlineStyleUrl => 'asset://flutter_assets/$assetPath';
}
