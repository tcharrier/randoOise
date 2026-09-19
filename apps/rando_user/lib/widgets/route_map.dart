import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../services/tile_cache.dart';

/// Map showing one or several routes with their start markers, plus optional
/// report / point-of-interest markers. Used by the list (map mode), the
/// detail header and the GPS tracking screen.
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
    this.extraLayers = const [],
    this.interactive = true,
    this.showStartMarkers = true,
    this.origin,
    this.pickedPoint,
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
  final List<Widget> extraLayers;
  final bool interactive;
  final bool showStartMarkers;
  final LatLng? origin;
  final LatLng? pickedPoint;

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<AppState>().offline;
    final style = offline.style;
    final scheme = Theme.of(context).colorScheme;

    final polylines = <Polyline>[];
    for (final it in itineraires) {
      final isMain = highlighted == null || it.id == highlighted!.id;
      for (final line in it.tracks) {
        polylines.add(Polyline(
          points: line,
          color: isMain ? RandoColors.track : RandoColors.track.withValues(alpha: 0.45),
          strokeWidth: isMain ? 4.5 : 3,
          borderColor: Colors.white.withValues(alpha: isMain ? 0.9 : 0.5),
          borderStrokeWidth: isMain ? 2 : 1,
        ));
      }
    }

    final markers = <Marker>[];
    if (showStartMarkers) {
      for (final it in itineraires) {
        markers.add(Marker(
          point: it.start,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: onRouteTap == null ? null : () => onRouteTap!(it),
            child: _Pin(
              color: highlighted == null || it.id == highlighted!.id
                  ? RandoColors.forest
                  : RandoColors.inkMuted,
              icon: Icons.hiking,
            ),
          ),
        ));
      }
    }
    for (final s in signalements) {
      markers.add(Marker(
        point: s.position,
        width: 34,
        height: 34,
        child: GestureDetector(
          onTap: onSignalementTap == null ? null : () => onSignalementTap!(s),
          child: _Dot(color: s.statut.color, icon: s.categorie.icon),
        ),
      ));
    }
    for (final e in elements) {
      markers.add(Marker(
        point: e.position,
        width: 34,
        height: 34,
        child: GestureDetector(
          onTap: onElementTap == null ? null : () => onElementTap!(e),
          child: _Dot(
            color: e.isValide ? RandoColors.water : RandoColors.inkMuted,
            icon: e.categorie.icon,
          ),
        ),
      ));
    }
    if (origin != null) {
      markers.add(Marker(
        point: origin!,
        width: 36,
        height: 36,
        alignment: Alignment.topCenter,
        child: const _Pin(color: RandoColors.ochre, icon: Icons.flag),
      ));
    }
    if (pickedPoint != null) {
      markers.add(Marker(
        point: pickedPoint!,
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: const _Pin(color: RandoColors.danger, icon: Icons.place),
      ));
    }

    final fit = initialFit ??
        (highlighted?.bounds ??
            (itineraires.isEmpty
                ? null
                : itineraires
                    .map((e) => e.bounds)
                    .reduce((a, b) => a.extend(b))));

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter ?? const LatLng(49.42, 2.85),
        initialZoom: initialZoom,
        initialCameraFit: initialCenter != null || fit == null
            ? null
            : CameraFit.bounds(
                bounds: toLatLngBounds(fit),
                padding: const EdgeInsets.all(36),
                maxZoom: 16,
              ),
        minZoom: 6,
        maxZoom: 19,
        backgroundColor: scheme.surfaceContainer,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onTap: onMapTap == null ? null : (_, p) => onMapTap!(p),
        onLongPress: onMapLongPress == null ? null : (_, p) => onMapLongPress!(p),
      ),
      children: [
        buildTileLayer(offline.tiles, style),
        PolylineLayer(polylines: polylines),
        ...extraLayers,
        MarkerLayer(markers: markers),
        SimpleAttributionWidget(
          source: Text(style.attribution, style: const TextStyle(fontSize: 10)),
          backgroundColor: scheme.surface.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          CustomPaint(size: const Size(10, 8), painter: _TrianglePainter(color)),
        ],
      );
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
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
        child: Icon(icon, size: 16, color: Colors.white),
      );
}

/// Blue location dot with accuracy circle for the tracking screen.
List<Widget> userLocationLayers(LatLng position, double accuracyM, {double? heading}) => [
      CircleLayer(circles: [
        CircleMarker(
          point: position,
          radius: accuracyM.clamp(5, 200),
          useRadiusInMeter: true,
          color: RandoColors.water.withValues(alpha: 0.12),
          borderColor: RandoColors.water.withValues(alpha: 0.4),
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
              color: RandoColors.water,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
            ),
          ),
        ),
      ]),
    ];
