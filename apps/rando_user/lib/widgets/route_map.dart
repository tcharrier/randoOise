import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';

/// A point of interest drawn on the map as a coloured icon (reports, points
/// of interest, origin, picked position…).
class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.color,
    required this.icon,
    this.data,
    this.size = 30,
    this.label,
  });

  final String id;
  final ll.LatLng position;
  final Color color;
  final IconData icon;
  final Object? data;
  final double size;
  final String? label;

  String get imageKey => 'mk-${icon.codePoint}-${icon.fontFamily}-${color.toARGB32().toRadixString(16)}-${size.round()}';
}

/// Reusable MapLibre GL map showing routes (hikes and cycling lanes), start
/// pins, markers, the user position, the GPS trail of the current outing and
/// the trajectory of a past outing. Ported from CycloARC's RouteMap.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    this.itineraires = const [],
    this.secondaryItineraires = const [],
    this.highlightedId,
    this.markers = const [],
    this.userLocation,
    this.userAccuracyM,
    this.trail,
    this.actualTrajectory,
    this.initialFit,
    this.initialCenter,
    this.initialZoom = 12,
    this.fitPadding = const EdgeInsets.all(40),
    this.interactive = true,
    this.showStartMarkers = true,
    this.showLabels = false,
    this.labelBuilder,
    this.onRouteTap,
    this.onMarkerTap,
    this.onMapTap,
    this.onMapLongPress,
    this.onMapReady,
    this.onCameraTrackingDismissed,
    this.onCameraIdle,
    this.compass = false,
    this.attribution = true,
  });

  final List<Itineraire> itineraires;

  /// Cycling segments outside the numbered plan ("autre aménagement
  /// cyclable"): drawn thin and grey, never tappable, no start pin.
  final List<Itineraire> secondaryItineraires;

  /// Route drawn on top, thicker; the others are faded.
  final String? highlightedId;
  final List<MapMarker> markers;
  final ll.LatLng? userLocation;
  final double? userAccuracyM;

  /// GPS trail of the outing in progress.
  final List<ll.LatLng>? trail;

  /// Trajectory of a finished outing (drawn in turquoise).
  final List<ll.LatLng>? actualTrajectory;
  final GeoBounds? initialFit;
  final ll.LatLng? initialCenter;
  final double initialZoom;
  final EdgeInsets fitPadding;
  final bool interactive;
  final bool showStartMarkers;

  /// Name pills next to the start pins (recomputed when the camera idles).
  final bool showLabels;
  final String Function(Itineraire)? labelBuilder;
  final void Function(Itineraire)? onRouteTap;
  final void Function(MapMarker)? onMarkerTap;
  final void Function(ll.LatLng)? onMapTap;
  final void Function(ll.LatLng)? onMapLongPress;
  final void Function(RouteMapState state)? onMapReady;
  final VoidCallback? onCameraTrackingDismissed;
  final VoidCallback? onCameraIdle;
  final bool compass;
  final bool attribution;

  @override
  State<RouteMap> createState() => RouteMapState();
}

class RouteMapState extends State<RouteMap> {
  ml.MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _layersAdded = false;
  final Set<String> _images = {};
  double _dpr = 2;
  Timer? _labelTimer;
  List<({Itineraire it, Offset point})> _labels = const [];
  bool _labelsHidden = false;
  bool _disposed = false;

  // Basemap style is created once per style id: changing the style string
  // would reload the map, so light/dark is applied through the controller.
  String? _styleId;
  String? _styleJson;
  bool _styleDark = false;
  bool _rasterDark = false;
  bool? _themeDark;

  ml.MapLibreMapController? get controller => _controller;
  bool get isReady => _styleLoaded && _controller != null;

  // ---------------------------------------------------------------- style

  static const _srcRoutes = 'routes';
  static const _srcSelected = 'selected';
  static const _srcStarts = 'starts';
  static const _srcMarkers = 'markers';
  static const _srcTrail = 'trail';
  static const _srcActual = 'actual';
  static const _srcUser = 'user';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final changed = _themeDark != null && _themeDark != dark;
    _themeDark = dark;
    if (changed && _styleLoaded && _controller != null) _applyTheme();
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isReady || !_layersAdded) return;
    final routesChanged = !_sameRoutes(oldWidget.itineraires, widget.itineraires) ||
        !_sameRoutes(oldWidget.secondaryItineraires, widget.secondaryItineraires) ||
        oldWidget.highlightedId != widget.highlightedId ||
        oldWidget.showStartMarkers != widget.showStartMarkers;
    if (routesChanged) {
      _setRoutes();
      _scheduleLabels();
    }
    if (!_sameMarkers(oldWidget.markers, widget.markers)) _setMarkers();
    if (!_samePoints(oldWidget.trail, widget.trail)) _setSource(_srcTrail, _lineFeature(widget.trail));
    if (!_samePoints(oldWidget.actualTrajectory, widget.actualTrajectory)) {
      _setSource(_srcActual, _lineFeature(widget.actualTrajectory));
    }
    if (oldWidget.userLocation != widget.userLocation || oldWidget.userAccuracyM != widget.userAccuracyM) {
      _setSource(_srcUser, _userFeature());
    }
    if (oldWidget.showLabels != widget.showLabels) _scheduleLabels();
  }

  @override
  void dispose() {
    _disposed = true;
    _labelTimer?.cancel();
    _controller?.removeListener(_onCameraChanged);
    _controller = null;
    super.dispose();
  }

  // --------------------------------------------------------------- camera

  Future<void> fitToBounds(GeoBounds b, {EdgeInsets? padding, bool animate = true}) async {
    final c = _controller;
    if (c == null) return;
    final p = padding ?? widget.fitPadding;
    final update = ml.CameraUpdate.newLatLngBounds(
      _toBounds(b),
      left: p.left,
      top: p.top,
      right: p.right,
      bottom: p.bottom,
    );
    if (animate) {
      await c.animateCamera(update, duration: const Duration(milliseconds: 500));
    } else {
      await c.moveCamera(update);
    }
  }

  Future<void> fitToRoute(Itineraire it, {EdgeInsets? padding}) => fitToBounds(it.bounds.pad(120), padding: padding);

  Future<void> fitAll({EdgeInsets? padding}) async {
    final b = _allBounds();
    if (b != null) await fitToBounds(b, padding: padding);
  }

  Future<void> moveTo(ll.LatLng target, double zoom, {bool animate = true}) async {
    final c = _controller;
    if (c == null) return;
    final u = ml.CameraUpdate.newLatLngZoom(ml.LatLng(target.latitude, target.longitude), zoom);
    if (animate) {
      await c.animateCamera(u, duration: const Duration(milliseconds: 500));
    } else {
      await c.moveCamera(u);
    }
  }

  Future<void> animateTo(ml.CameraPosition position, {Duration duration = const Duration(milliseconds: 500)}) async {
    await _controller?.animateCamera(ml.CameraUpdate.newCameraPosition(position), duration: duration);
  }

  ml.CameraPosition? get cameraPosition => _controller?.cameraPosition;

  Future<Offset?> toScreen(ll.LatLng p) async {
    final c = _controller;
    if (c == null) return null;
    try {
      final pt = await c.toScreenLocation(ml.LatLng(p.latitude, p.longitude));
      return Offset(pt.x.toDouble(), pt.y.toDouble());
    } catch (_) {
      return null;
    }
  }

  GeoBounds? _allBounds() {
    GeoBounds? b;
    for (final it in widget.itineraires) {
      b = b == null ? it.bounds : b.extend(it.bounds);
    }
    for (final pts in [widget.trail, widget.actualTrajectory]) {
      final pb = pts == null ? null : GeoBounds.fromPoints(pts);
      if (pb != null) b = b == null ? pb : b.extend(pb);
    }
    return b;
  }

  static ml.LatLngBounds _toBounds(GeoBounds b) => ml.LatLngBounds(
        southwest: ml.LatLng(b.minLat, b.minLng),
        northeast: ml.LatLng(b.maxLat, b.maxLng),
      );

  // ------------------------------------------------------------- lifecycle

  void _onMapCreated(ml.MapLibreMapController c) {
    // A style change recreates the platform map: start from scratch.
    _controller?.removeListener(_onCameraChanged);
    // The platform view may be created after the widget was already
    // disposed (page popped quickly): ignore the controller in that case.
    if (_disposed) return;
    _controller = c;
    _styleLoaded = false;
    _layersAdded = false;
    _images.clear();
    _rasterDark = _styleDark;
    c.addListener(_onCameraChanged);
  }

  Future<void> _onStyleLoaded() async {
    if (_disposed || !mounted) return;
    _styleLoaded = true;
    _layersAdded = false;
    await _addLayers();
    if (_disposed) return;
    _layersAdded = true;
    await _applyTheme();
    if (_disposed) return;
    final fit = widget.initialFit ?? (widget.initialCenter == null ? _allBounds() : null);
    if (fit != null) {
      await fitToBounds(fit, animate: false);
    }
    widget.onMapReady?.call(this);
    _scheduleLabels();
  }

  void _onCameraChanged() {
    if (!widget.showLabels) return;
    if (!_labelsHidden && mounted) setState(() => _labelsHidden = true);
    _scheduleLabels();
  }

  void _scheduleLabels() {
    if (!widget.showLabels) {
      if (_labels.isNotEmpty && mounted) setState(() => _labels = const []);
      return;
    }
    _labelTimer?.cancel();
    _labelTimer = Timer(const Duration(milliseconds: 160), _computeLabels);
  }

  Future<void> _computeLabels() async {
    final c = _controller;
    if (c == null || !mounted || !widget.showStartMarkers) return;
    final its = widget.itineraires;
    if (its.isEmpty) {
      if (mounted) setState(() => _labels = const []);
      return;
    }
    try {
      final zoom = c.cameraPosition?.zoom ?? widget.initialZoom;
      final size = context.size ?? const Size(400, 800);
      // Highlighted route first so it always keeps its label.
      final ordered = [
        ...its.where((e) => e.id == widget.highlightedId),
        ...its.where((e) => e.id != widget.highlightedId),
      ];
      final pts = await c.toScreenLocationBatch(ordered.map((e) => ml.LatLng(e.start.latitude, e.start.longitude)));
      if (!mounted) return;
      final out = <({Itineraire it, Offset point})>[];
      final placed = <Rect>[];
      for (var i = 0; i < ordered.length && i < pts.length; i++) {
        final it = ordered[i];
        final p = Offset(pts[i].x.toDouble(), pts[i].y.toDouble());
        final isSelected = it.id == widget.highlightedId;
        // Far out, only the selected route is labelled; otherwise labels
        // are placed greedily and never overlap each other.
        if (!isSelected && zoom < 11.5) continue;
        if (p.dx < -90 || p.dx > size.width + 90 || p.dy < 0 || p.dy > size.height + 40) continue;
        final rect = Rect.fromCenter(center: Offset(p.dx, p.dy - 40), width: 170, height: 30);
        if (!isSelected && placed.any((q) => q.overlaps(rect))) continue;
        placed.add(rect);
        out.add((it: it, point: p));
      }
      setState(() {
        _labels = out;
        _labelsHidden = false;
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------- layers

  /// Runs one controller call; a disposed map or a platform error must never
  /// surface as an unhandled exception. Returns false when the sequence must
  /// stop (widget disposed).
  Future<bool> _step(String name, Future<void> Function(ml.MapLibreMapController c) body) async {
    if (_disposed) return false;
    final c = _controller;
    if (c == null) return false;
    try {
      await body(c);
    } catch (e) {
      debugPrint('RouteMap: étape "$name" en échec : $e');
    }
    return !_disposed;
  }

  Future<void> _addLayers() async {
    if (_controller == null || !mounted) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final steps = <(String, Future<void> Function(ml.MapLibreMapController c))>[
      ('routes-source', (c) => c.addGeoJsonSource(_srcRoutes, _routesCollection())),
      (
        'routes-outline',
        (c) => c.addLineLayer(
              _srcRoutes,
              'routes-outline',
              const ml.LineLayerProperties(
                lineColor: '#FFFFFF',
                lineWidth: ['get', 'outline'],
                lineOpacity: ['get', 'opacityOutline'],
                lineJoin: 'round',
                lineCap: 'round',
              ),
              enableInteraction: false,
            )
      ),
      (
        'routes-line',
        (c) => c.addLineLayer(
              _srcRoutes,
              'routes-line',
              const ml.LineLayerProperties(
                lineColor: ['get', 'color'],
                lineWidth: ['get', 'width'],
                lineOpacity: ['get', 'opacity'],
                lineJoin: 'round',
                lineCap: 'round',
              ),
              filter: ['==', ['get', 'dashed'], false],
              enableInteraction: false,
            )
      ),
      (
        'routes-dashed',
        (c) => c.addLineLayer(
              _srcRoutes,
              'routes-dashed',
              const ml.LineLayerProperties(
                lineColor: ['get', 'color'],
                lineWidth: ['get', 'width'],
                lineOpacity: ['get', 'opacity'],
                lineJoin: 'round',
                lineCap: 'butt',
                lineDasharray: [2.2, 1.6],
              ),
              filter: ['==', ['get', 'dashed'], true],
              enableInteraction: false,
            )
      ),
      ('selected-source', (c) => c.addGeoJsonSource(_srcSelected, _selectedCollection())),
      (
        'selected-outline',
        (c) => c.addLineLayer(
              _srcSelected,
              'selected-outline',
              const ml.LineLayerProperties(lineColor: '#FFFFFF', lineWidth: 9, lineOpacity: 0.95, lineJoin: 'round', lineCap: 'round'),
              enableInteraction: false,
            )
      ),
      (
        'selected-line',
        (c) => c.addLineLayer(
              _srcSelected,
              'selected-line',
              const ml.LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 5.5, lineOpacity: 1, lineJoin: 'round', lineCap: 'round'),
              enableInteraction: false,
            )
      ),
      ('actual-source', (c) => c.addGeoJsonSource(_srcActual, _lineFeature(widget.actualTrajectory))),
      (
        'actual-outline',
        (c) => c.addLineLayer(
              _srcActual,
              'actual-outline',
              const ml.LineLayerProperties(lineColor: '#FFFFFF', lineWidth: 7.5, lineOpacity: 0.85, lineJoin: 'round', lineCap: 'round'),
              enableInteraction: false,
            )
      ),
      (
        'actual-line',
        (c) => c.addLineLayer(
              _srcActual,
              'actual-line',
              ml.LineLayerProperties(lineColor: _hex(RandoColors.velo), lineWidth: 4.5, lineOpacity: 0.95, lineJoin: 'round', lineCap: 'round'),
              enableInteraction: false,
            )
      ),
      ('trail-source', (c) => c.addGeoJsonSource(_srcTrail, _lineFeature(widget.trail))),
      (
        'trail-line',
        (c) => c.addLineLayer(
              _srcTrail,
              'trail-line',
              ml.LineLayerProperties(
                lineColor: _trailColor(dark),
                lineWidth: 5,
                lineOpacity: 0.8,
                lineJoin: 'round',
                lineCap: 'round',
              ),
              enableInteraction: false,
            )
      ),
      ('user-source', (c) => c.addGeoJsonSource(_srcUser, _userFeature())),
      (
        'user-glow',
        (c) => c.addCircleLayer(
              _srcUser,
              'user-glow',
              ml.CircleLayerProperties(circleRadius: ['get', 'glow'], circleColor: _hex(RandoColors.blue), circleOpacity: 0.12),
              enableInteraction: false,
            )
      ),
      (
        'user-halo',
        (c) => c.addCircleLayer(
              _srcUser,
              'user-halo',
              ml.CircleLayerProperties(circleRadius: 12, circleColor: _hex(RandoColors.blue), circleOpacity: 0.25, circleStrokeWidth: 2, circleStrokeColor: '#FFFFFF'),
              enableInteraction: false,
            )
      ),
      (
        'user-dot',
        (c) => c.addCircleLayer(
              _srcUser,
              'user-dot',
              ml.CircleLayerProperties(circleRadius: 6, circleColor: _hex(RandoColors.blue), circleOpacity: 1, circleStrokeWidth: 2.5, circleStrokeColor: '#FFFFFF'),
              enableInteraction: false,
            )
      ),
      ('start-images', (c) => _ensureStartImages()),
      ('starts-source', (c) => c.addGeoJsonSource(_srcStarts, _startsCollection())),
      // Coloured disc drawn under the symbol: visible even if the icon image
      // could not be registered on this platform.
      (
        'starts-circles',
        (c) => c.addCircleLayer(
              _srcStarts,
              'starts-circles',
              const ml.CircleLayerProperties(circleRadius: 9, circleColor: ['get', 'color'], circleStrokeWidth: 2, circleStrokeColor: '#FFFFFF'),
              enableInteraction: false,
            )
      ),
      (
        'starts-symbols',
        (c) => c.addSymbolLayer(
              _srcStarts,
              'starts-symbols',
              ml.SymbolLayerProperties(
                iconImage: ['get', 'icon'],
                iconSize: 1 / _dpr,
                iconAllowOverlap: true,
                iconIgnorePlacement: true,
                iconAnchor: 'center',
              ),
              enableInteraction: false,
            )
      ),
      ('marker-images', (c) => _ensureMarkerImages(widget.markers)),
      ('markers-source', (c) => c.addGeoJsonSource(_srcMarkers, _markersCollection())),
      (
        'markers-circles',
        (c) => c.addCircleLayer(
              _srcMarkers,
              'markers-circles',
              const ml.CircleLayerProperties(circleRadius: 8, circleColor: ['get', 'color'], circleStrokeWidth: 2, circleStrokeColor: '#FFFFFF'),
              enableInteraction: false,
            )
      ),
      (
        'markers-symbols',
        (c) => c.addSymbolLayer(
              _srcMarkers,
              'markers-symbols',
              ml.SymbolLayerProperties(
                iconImage: ['get', 'icon'],
                iconSize: 1 / _dpr,
                iconAllowOverlap: true,
                iconIgnorePlacement: true,
                iconAnchor: 'center',
              ),
              enableInteraction: false,
            )
      ),
    ];
    for (final (name, body) in steps) {
      if (!await _step(name, body)) return;
    }
    // The theme may have flipped while the layers were being added.
    if (mounted && (Theme.of(context).brightness == Brightness.dark) != dark) {
      _layersAdded = true;
      await _applyTheme();
    }
  }

  static String _trailColor(bool dark) => _hex(dark ? RandoColors.nightGreen : RandoColors.greenBright);

  /// Dims the raster basemap in dark mode through the controller, so the
  /// platform view survives a light/dark switch.
  Future<void> _applyRasterTheme(bool dark) async {
    final id = _styleId;
    if (id == null || _rasterDark == dark) return;
    _rasterDark = dark;
    await _step(
      'raster-theme',
      (c) => c.setLayerProperties(
        '$id-raster',
        ml.RasterLayerProperties(
          rasterBrightnessMax: dark ? 0.72 : 1.0,
          rasterBrightnessMin: dark ? 0.05 : 0.0,
          rasterSaturation: dark ? -0.4 : 0.0,
          rasterContrast: dark ? 0.05 : 0.0,
        ),
      ),
    );
  }

  /// Re-applies everything that depends on the brightness.
  Future<void> _applyTheme() async {
    if (!mounted || !_styleLoaded) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    await _applyRasterTheme(dark);
    if (_disposed || !_layersAdded) return;
    await _step('trail-theme', (c) => c.setLayerProperties('trail-line', ml.LineLayerProperties(lineColor: _trailColor(dark), lineWidth: 5, lineOpacity: 0.8, lineJoin: 'round', lineCap: 'round')));
    if (_disposed) return;
    await _setRoutes();
  }

  Future<void> _setSource(String id, Map<String, dynamic> data) async {
    final c = _controller;
    if (c == null || !_layersAdded) return;
    try {
      await c.setGeoJsonSource(id, data);
    } catch (_) {}
  }

  Future<void> _setRoutes() async {
    await _setSource(_srcRoutes, _routesCollection());
    await _setSource(_srcSelected, _selectedCollection());
    await _ensureStartImages();
    await _setSource(_srcStarts, _startsCollection());
  }

  Future<void> _setMarkers() async {
    await _ensureMarkerImages(widget.markers);
    await _setSource(_srcMarkers, _markersCollection());
  }

  // ------------------------------------------------------------- geojson

  /// Official plan colour of a numbered cycling route, when known.
  static Color? _planColor(Itineraire it) => (it.isVelo && it.couleur != null) ? Color(it.couleur!) : null;

  Color _routeColor(Itineraire it, bool dark) =>
      _planColor(it) ??
      (it.isVelo
          ? (dark ? RandoColors.trackVeloNight : RandoColors.trackVelo)
          : (dark ? RandoColors.trackNight : RandoColors.track));

  Map<String, dynamic> _routesCollection() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasSelection = widget.highlightedId != null;
    final features = <Map<String, dynamic>>[];
    for (final it in widget.secondaryItineraires) {
      for (final line in it.tracks) {
        if (line.length < 2) continue;
        features.add({
          'type': 'Feature',
          'properties': {
            'id': it.id,
            'color': dark ? '#8A8A8A' : '#9A9A9A',
            'width': 2.0,
            'outline': 3.0,
            'opacity': hasSelection ? 0.3 : 0.7,
            'opacityOutline': 0.5,
            'dashed': false,
          },
          'geometry': {'type': 'LineString', 'coordinates': line.map((p) => [p.longitude, p.latitude]).toList()},
        });
      }
    }
    for (final it in widget.itineraires) {
      if (it.id == widget.highlightedId) continue; // drawn by the selected source
      final faded = hasSelection;
      final dashed = it.statutReseau == StatutReseau.enTravaux || it.statutReseau == StatutReseau.provisoire;
      for (final line in it.tracks) {
        if (line.length < 2) continue;
        features.add({
          'type': 'Feature',
          'properties': {
            'id': it.id,
            'color': _hex(_routeColor(it, dark)),
            'width': faded ? 3.0 : 4.5,
            'outline': faded ? 4.5 : 7.0,
            'opacity': faded ? 0.35 : 0.95,
            'opacityOutline': faded ? 0.3 : 0.9,
            'dashed': dashed,
          },
          'geometry': {'type': 'LineString', 'coordinates': line.map((p) => [p.longitude, p.latitude]).toList()},
        });
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Map<String, dynamic> _selectedCollection() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final features = <Map<String, dynamic>>[];
    final id = widget.highlightedId;
    if (id != null) {
      for (final it in widget.itineraires.where((e) => e.id == id)) {
        for (final line in it.tracks) {
          if (line.length < 2) continue;
          features.add({
            'type': 'Feature',
            'properties': {'id': it.id, 'color': _hex(_routeColor(it, dark))},
            'geometry': {'type': 'LineString', 'coordinates': line.map((p) => [p.longitude, p.latitude]).toList()},
          });
        }
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Color _startColor(Itineraire it) => _planColor(it) ?? (it.isVelo ? RandoColors.velo : RandoColors.green);

  String? _startNumber(Itineraire it) {
    final n = it.numero;
    return (it.isVelo && n != null && n.isNotEmpty) ? n : null;
  }

  /// One image per colour / number / selection state:
  /// Keys look like `start-hex-kind-on` (or `-off`).
  String _startImageKey(Itineraire it) {
    final selected = widget.highlightedId == null || it.id == widget.highlightedId;
    final hex = _startColor(it).toARGB32().toRadixString(16);
    final n = _startNumber(it);
    final kind = n == null ? (it.isVelo ? 'bike' : 'hike') : 'n$n';
    return 'start-$hex-$kind-${selected ? 'on' : 'off'}';
  }

  Map<String, dynamic> _startsCollection() {
    if (!widget.showStartMarkers) return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final it in widget.itineraires)
          {
            'type': 'Feature',
            'properties': {'id': it.id, 'icon': _startImageKey(it), 'color': _hex(_startColor(it))},
            'geometry': {'type': 'Point', 'coordinates': [it.start.longitude, it.start.latitude]},
          },
      ],
    };
  }

  Map<String, dynamic> _markersCollection() => {
        'type': 'FeatureCollection',
        'features': [
          for (final m in widget.markers)
            {
              'type': 'Feature',
              'properties': {'id': m.id, 'icon': m.imageKey, 'color': _hex(m.color)},
              'geometry': {'type': 'Point', 'coordinates': [m.position.longitude, m.position.latitude]},
            },
        ],
      };

  Map<String, dynamic> _lineFeature(List<ll.LatLng>? pts) => {
        'type': 'FeatureCollection',
        'features': [
          if (pts != null && pts.length >= 2)
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {'type': 'LineString', 'coordinates': pts.map((p) => [p.longitude, p.latitude]).toList()},
            },
        ],
      };

  Map<String, dynamic> _userFeature() {
    final p = widget.userLocation;
    if (p == null) return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
    final acc = (widget.userAccuracyM ?? 20).clamp(8, 80);
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'glow': 14 + acc / 4},
          'geometry': {'type': 'Point', 'coordinates': [p.longitude, p.latitude]},
        },
      ],
    };
  }

  // --------------------------------------------------------------- images

  Future<void> _ensureStartImages() async {
    if (!widget.showStartMarkers) return;
    final seen = <String>{};
    for (final it in widget.itineraires) {
      final key = _startImageKey(it);
      if (_images.contains(key) || !seen.add(key)) continue;
      final on = key.endsWith('-on');
      await _addImage(
        key,
        icon: it.isVelo ? Icons.directions_bike_rounded : Icons.hiking_rounded,
        text: _startNumber(it),
        color: on ? _startColor(it) : RandoColors.inkSoft,
        size: on ? 34 : 28,
      );
      if (_disposed) return;
    }
  }

  Future<void> _ensureMarkerImages(List<MapMarker> markers) async {
    for (final m in markers) {
      if (_images.contains(m.imageKey)) continue;
      await _addImage(m.imageKey, icon: m.icon, color: m.color, size: m.size);
      if (_disposed) return;
    }
  }

  Future<void> _addImage(String key, {required IconData icon, required Color color, required double size, String? text}) async {
    final c = _controller;
    if (c == null) return;
    try {
      final bytes = await _renderMarker(icon: icon, color: color, size: size, dpr: _dpr, text: text);
      if (bytes == null || _disposed) return;
      await c.addImage(key, bytes);
      _images.add(key);
    } catch (e) {
      debugPrint('RouteMap: image "$key" en échec : $e');
    }
  }

  /// Draws a white-ringed coloured disc with a Material icon inside.
  static Future<Uint8List?> _renderMarker({
    required IconData icon,
    required Color color,
    required double size,
    required double dpr,
    String? text,
  }) async {
    final px = (size + 6) * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(px / 2, px / 2);
    final r = size / 2 * dpr;
    canvas.drawCircle(center.translate(0, 1.5 * dpr), r + 1.5 * dpr, Paint()..color = Colors.black.withValues(alpha: 0.22));
    canvas.drawCircle(center, r + 1.5 * dpr, Paint()..color = Colors.white);
    canvas.drawCircle(center, r, Paint()..color = color);
    final hasText = text != null && text.isNotEmpty;
    final textScale = hasText ? (text.length <= 2 ? 0.5 : (text.length == 3 ? 0.4 : 0.32)) : 0.56;
    final tp = TextPainter(
      text: TextSpan(
        text: hasText ? text : String.fromCharCode(icon.codePoint),
        style: hasText
            ? TextStyle(
                fontSize: size * textScale * dpr,
                fontFamily: kRandoDisplayFont,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )
            : TextStyle(
                fontSize: size * 0.56 * dpr,
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                color: Colors.white,
              ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    final image = await recorder.endRecording().toImage(px.ceil(), px.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  // ----------------------------------------------------------------- taps

  Future<void> _onMapClick(math.Point<double> point, ml.LatLng coord) async {
    final tapped = ll.LatLng(coord.latitude, coord.longitude);
    final mpp = await _metersPerPixel();

    // 1. markers
    if (widget.onMarkerTap != null && widget.markers.isNotEmpty) {
      MapMarker? best;
      var bestD = double.infinity;
      for (final m in widget.markers) {
        final d = haversineM(tapped, m.position);
        if (d < bestD) {
          bestD = d;
          best = m;
        }
      }
      if (best != null && bestD <= mpp * (best.size / 2 + 12)) {
        widget.onMarkerTap!(best);
        return;
      }
    }
    // 2. routes: start pins first, then the closest polyline
    if (widget.onRouteTap != null && widget.itineraires.isNotEmpty) {
      Itineraire? best;
      var bestD = double.infinity;
      if (widget.showStartMarkers) {
        for (final it in widget.itineraires) {
          final d = haversineM(tapped, it.start);
          if (d < bestD) {
            bestD = d;
            best = it;
          }
        }
        if (best != null && bestD <= mpp * 26) {
          widget.onRouteTap!(best);
          return;
        }
      }
      best = null;
      bestD = double.infinity;
      for (final it in widget.itineraires) {
        if (!it.bounds.pad(mpp * 30).contains(tapped)) continue;
        final d = distanceToTracksM(tapped, it.tracks);
        if (d < bestD) {
          bestD = d;
          best = it;
        }
      }
      if (best != null && bestD <= mpp * 22) {
        widget.onRouteTap!(best);
        return;
      }
    }
    widget.onMapTap?.call(tapped);
  }

  Future<double> _metersPerPixel() async {
    final c = _controller;
    final width = context.size?.width ?? 400;
    if (c == null) return 10;
    try {
      final region = await c.getVisibleRegion();
      final lat = (region.southwest.latitude + region.northeast.latitude) / 2;
      final span = haversineM(ll.LatLng(lat, region.southwest.longitude), ll.LatLng(lat, region.northeast.longitude));
      if (span > 0 && width > 0) return span / width;
    } catch (_) {}
    final zoom = c.cameraPosition?.zoom ?? widget.initialZoom;
    final lat = c.cameraPosition?.target.latitude ?? 49.4;
    return 78271.517 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);
  }

  // ------------------------------------------------------------------ misc

  static bool _sameRoutes(List<Itineraire> a, List<Itineraire> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  static bool _sameMarkers(List<MapMarker> a, List<MapMarker> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].imageKey != b[i].imageKey || a[i].position != b[i].position) return false;
    }
    return true;
  }

  static bool _samePoints(List<ll.LatLng>? a, List<ll.LatLng>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.isEmpty || (a.first == b.first && a.last == b.last);
  }

  static String _hex(Color c) =>
      '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';

  ml.CameraPosition _initialCamera() {
    final center = widget.initialCenter;
    if (center != null) {
      return ml.CameraPosition(target: ml.LatLng(center.latitude, center.longitude), zoom: widget.initialZoom);
    }
    final b = widget.initialFit ?? _allBounds();
    if (b == null) {
      return const ml.CameraPosition(target: ml.LatLng(49.42, 2.85), zoom: 10.5);
    }
    // Rough zoom from the bounding box; the exact fit happens on style load.
    final lngSpan = math.max(b.maxLng - b.minLng, 0.002);
    final latSpan = math.max(b.maxLat - b.minLat, 0.002);
    final zLng = math.log(360 / lngSpan * 0.8) / math.ln2 - 1;
    final zLat = math.log(180 / latSpan * 0.8) / math.ln2 - 1;
    final zoom = math.min(zLng, zLat).clamp(6.0, 16.0);
    return ml.CameraPosition(target: ml.LatLng(b.center.latitude, b.center.longitude), zoom: zoom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final style = context.watch<AppState>().offline.style;
    _dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    if (_styleId != style.id) {
      // New basemap: the platform view is recreated (key below) with the
      // style document for the current brightness.
      _styleId = style.id;
      _styleDark = dark;
      _rasterDark = dark;
      _styleJson = style.styleJson(dark: dark);
    }

    final map = ml.MapLibreMap(
      key: ValueKey(style.id),
      styleString: _styleJson!,
      // Everything is drawn with style layers; skipping the annotation
      // managers avoids an "addSource when a newer style is loading" error
      // logged by the plugin when the style is swapped early.
      annotationOrder: const [],
      initialCameraPosition: _initialCamera(),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapClick: widget.interactive ? _onMapClick : null,
      onMapLongClick: widget.interactive && widget.onMapLongPress != null
          ? (_, c) => widget.onMapLongPress!(ll.LatLng(c.latitude, c.longitude))
          : null,
      onCameraTrackingDismissed: widget.onCameraTrackingDismissed,
      onCameraIdle: () {
        widget.onCameraIdle?.call();
        _scheduleLabels();
      },
      trackCameraPosition: true,
      compassEnabled: widget.compass,
      rotateGesturesEnabled: widget.interactive,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      tiltGesturesEnabled: widget.interactive,
      doubleClickZoomEnabled: widget.interactive,
      dragEnabled: widget.interactive,
      myLocationEnabled: false,
      attributionButtonMargins: const math.Point(-100, -100),
      logoViewMargins: const math.Point(-100, -100),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: widget.interactive ? map : IgnorePointer(child: map)),
        if (widget.showLabels && !_labelsHidden)
          for (final l in _labels)
            Positioned(
              left: l.point.dx - 90,
              top: l.point.dy - 52,
              width: 180,
              child: IgnorePointer(
                ignoring: widget.onRouteTap == null,
                child: Center(
                  child: _LabelPill(
                    widget.labelBuilder?.call(l.it) ?? l.it.titre,
                    muted: widget.highlightedId != null && widget.highlightedId != l.it.id,
                    color: _planColor(l.it),
                    onTap: widget.onRouteTap == null ? null : () => widget.onRouteTap!(l.it),
                  ),
                ),
              ),
            ),
        if (widget.attribution)
          Positioned(
            right: 6,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(style.attribution, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9.5)),
              ),
            ),
          ),
      ],
    );
  }
}

class _LabelPill extends StatelessWidget {
  const _LabelPill(this.text, {this.muted = false, this.onTap, this.color});
  final String text;
  final Color? color;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 176),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: muted ? scheme.surface.withValues(alpha: 0.88) : (color ?? scheme.onSurface),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kRandoFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: muted
                ? scheme.onSurface
                : (color == null ? scheme.surface : (color!.computeLuminance() > 0.6 ? Colors.black87 : Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// Convenience for building report / point-of-interest markers.
MapMarker signalementMarker(Signalement s) => MapMarker(
      id: 'sig-${s.id}',
      position: s.position,
      color: s.statut.color,
      icon: s.categorie.icon,
      data: s,
    );

MapMarker elementMarker(ElementRemarquable e) => MapMarker(
      id: 'elem-${e.id}',
      position: e.position,
      color: e.isValide ? RandoColors.blue : RandoColors.inkSoft,
      icon: e.categorie.icon,
      data: e,
    );
