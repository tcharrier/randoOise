import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../services/tile_cache.dart';

/// Map showing one or several routes with their start markers, plus optional
/// report / point-of-interest markers. Used by the map tab, the detail
/// header, the forms and the GPS tracking screen.
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.itineraires,
    this.highlighted,
    this.signalements = const [],
    this.elements = const [],
    this.controller,
    this.initialFit,
    this.initialCenter,
    this.initialZoom = 12,
    this.onRouteTap,
    this.onSignalementTap,
    this.onElementTap,
    this.onMapTap,
    this.onMapLongPress,
    this.onPositionChanged,
    this.extraLayers = const [],
    this.interactive = true,
    this.showStartMarkers = true,
    this.showLabels = false,
    this.labelBuilder,
    this.origin,
    this.pickedPoint,
    this.attribution = true,
    this.fitPadding = 40,
  });

  final List<Itineraire> itineraires;
  final Itineraire? highlighted;
  final List<Signalement> signalements;
  final List<ElementRemarquable> elements;
  final MapController? controller;
  final GeoBounds? initialFit;
  final LatLng? initialCenter;
  final double initialZoom;
  final void Function(Itineraire)? onRouteTap;
  final void Function(Signalement)? onSignalementTap;
  final void Function(ElementRemarquable)? onElementTap;
  final void Function(LatLng)? onMapTap;
  final void Function(LatLng)? onMapLongPress;
  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;
  final List<Widget> extraLayers;
  final bool interactive;
  final bool showStartMarkers;

  /// Show a name pill above every start marker (map tab).
  final bool showLabels;
  final String Function(Itineraire)? labelBuilder;
  final LatLng? origin;
  final LatLng? pickedPoint;
  final bool attribution;

  /// Padding used when fitting the camera to the routes.
  final double fitPadding;

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<AppState>().offline;
    final style = offline.style;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final trackColor = dark ? RandoColors.trackNight : RandoColors.track;

    final polylines = <Polyline>[];
    // Draw non-highlighted routes first so the selected one stays on top.
    final ordered = [
      ...itineraires.where((it) => highlighted != null && it.id != highlighted!.id),
      ...itineraires.where((it) => highlighted == null || it.id == highlighted!.id),
    ];
    for (final it in ordered) {
      final isMain = highlighted == null || it.id == highlighted!.id;
      for (final line in it.tracks) {
        polylines.add(Polyline(
          points: line,
          color: isMain ? trackColor : trackColor.withValues(alpha: 0.4),
          strokeWidth: isMain ? 5 : 3,
          borderColor: Colors.white.withValues(alpha: isMain ? 0.95 : 0.5),
          borderStrokeWidth: isMain ? 2 : 1,
        ));
      }
    }

    final markers = <Marker>[];
    if (showStartMarkers) {
      for (final it in itineraires) {
        final isMain = highlighted == null || it.id == highlighted!.id;
        final label = showLabels ? (labelBuilder?.call(it) ?? it.nom) : null;
        markers.add(Marker(
          point: it.start,
          width: label == null ? 44 : 190,
          height: label == null ? 48 : 84,
          alignment: Alignment.topCenter,
          child: Semantics(
            button: onRouteTap != null,
            label: 'Circuit ${it.nom}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRouteTap == null ? null : () => onRouteTap!(it),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null) ...[
                    _LabelPill(label, muted: !isMain),
                    const SizedBox(height: 4),
                  ],
                  _Pin(
                    color: isMain ? scheme.primary : RandoColors.inkSoft,
                    icon: Icons.hiking_rounded,
                    ring: isMain,
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }
    for (final s in signalements) {
      markers.add(Marker(
        point: s.position,
        width: 36,
        height: 36,
        child: Semantics(
          button: onSignalementTap != null,
          label: 'Signalement ${s.categorie.label}, ${s.statut.label}',
          child: GestureDetector(
            onTap: onSignalementTap == null ? null : () => onSignalementTap!(s),
            child: _Dot(color: s.statut.color, icon: s.categorie.icon),
          ),
        ),
      ));
    }
    for (final e in elements) {
      markers.add(Marker(
        point: e.position,
        width: 36,
        height: 36,
        child: Semantics(
          button: onElementTap != null,
          label: 'Élément remarquable ${e.titre}',
          child: GestureDetector(
            onTap: onElementTap == null ? null : () => onElementTap!(e),
            child: _Dot(color: e.isValide ? RandoColors.blue : RandoColors.inkSoft, icon: e.categorie.icon),
          ),
        ),
      ));
    }
    if (origin != null) {
      markers.add(Marker(
        point: origin!,
        width: 40,
        height: 44,
        alignment: Alignment.topCenter,
        child: const _Pin(color: RandoColors.ochre, icon: Icons.flag_rounded, ring: true),
      ));
    }
    if (pickedPoint != null) {
      markers.add(Marker(
        point: pickedPoint!,
        width: 48,
        height: 52,
        alignment: Alignment.topCenter,
        child: const _Pin(color: RandoColors.red, icon: Icons.place_rounded, ring: true, size: 36),
      ));
    }

    final fit = initialFit ??
        (highlighted?.bounds ??
            (itineraires.isEmpty
                ? null
                : itineraires.map((e) => e.bounds).reduce((a, b) => a.extend(b))));

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter ?? const LatLng(49.42, 2.85),
        initialZoom: initialZoom,
        initialCameraFit: initialCenter != null || fit == null
            ? null
            : CameraFit.bounds(
                bounds: toLatLngBounds(fit),
                padding: EdgeInsets.all(fitPadding),
                maxZoom: 16,
              ),
        minZoom: 6,
        maxZoom: 19,
        backgroundColor: scheme.surfaceContainer,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onTap: onMapTap == null ? null : (_, p) => onMapTap!(p),
        onLongPress: onMapLongPress == null ? null : (_, p) => onMapLongPress!(p),
        onPositionChanged: onPositionChanged,
      ),
      children: [
        buildTileLayer(offline.tiles, style),
        if (dark)
          // Dim bright tiles in dark mode so overlays stay readable.
          Container(color: Colors.black.withValues(alpha: 0.35)),
        PolylineLayer(polylines: polylines),
        ...extraLayers,
        MarkerLayer(markers: markers),
        if (attribution)
          SimpleAttributionWidget(
            source: Text(style.attribution, style: const TextStyle(fontSize: 10)),
            backgroundColor: scheme.surface.withValues(alpha: 0.85),
          ),
      ],
    );
  }
}

class _LabelPill extends StatelessWidget {
  const _LabelPill(this.text, {this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 186),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: muted ? scheme.surface.withValues(alpha: 0.85) : scheme.onSurface,
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
          color: muted ? scheme.onSurface : scheme.surface,
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon, this.ring = false, this.size = 32});
  final Color color;
  final IconData icon;
  final bool ring;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: ring ? 3 : 2),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Icon(icon, size: size * 0.55, color: Colors.white),
          ),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Icon(icon, size: 17, color: Colors.white),
      );
}

/// Blue location dot with accuracy circle for the tracking screen.
List<Widget> userLocationLayers(LatLng position, double accuracyM) => [
      CircleLayer(circles: [
        CircleMarker(
          point: position,
          radius: accuracyM.clamp(5, 200),
          useRadiusInMeter: true,
          color: RandoColors.blue.withValues(alpha: 0.12),
          borderColor: RandoColors.blue.withValues(alpha: 0.4),
          borderStrokeWidth: 1,
        ),
      ]),
      MarkerLayer(markers: [
        Marker(
          point: position,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: RandoColors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
            ),
          ),
        ),
      ]),
    ];
