import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../admin_data.dart';
import '../utils/palette.dart';
import '../widgets/map_focus.dart';
import '../widgets/map_overlays.dart';
import '../widgets/map_pin.dart';

/// Overview map with every route of the enabled sources, plus toggleable
/// reports / points of interest layers.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.focusController});

  final MapFocusController focusController;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _showSignalements = true;
  bool _showElements = true;
  SignalementStatut? _signalementFilter;
  ElementStatut? _elementFilter;
  String? _hoveredRouteId;
  Signalement? _selectedSignalement;
  ElementRemarquable? _selectedElement;

  @override
  void initState() {
    super.initState();
    widget.focusController.addListener(_onFocusRequest);
  }

  @override
  void dispose() {
    widget.focusController.removeListener(_onFocusRequest);
    super.dispose();
  }

  void _onFocusRequest() {
    final req = widget.focusController.request;
    if (req == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(req.point, 17);
    });
  }

  String? _nearestRouteId(LatLng point, List<Itineraire> routes) {
    String? best;
    var bestDist = double.infinity;
    for (final r in routes) {
      final d = distanceToTracksM(point, r.tracks);
      if (d < bestDist) {
        bestDist = d;
        best = r.id;
      }
    }
    return bestDist < 200 ? best : null;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AdminData>();
    final repo = context.read<RandoRepository>();
    final enabledSourceIds =
        data.sources.where((s) => s.enabled).map((s) => s.id).toSet();
    final routes = data.itineraires
        .where((it) => enabledSourceIds.contains(it.sourceId))
        .toList();

    GeoBounds? bounds;
    for (final r in routes) {
      bounds = bounds == null ? r.bounds : bounds.extend(r.bounds);
    }
    final latLngBounds =
        bounds == null ? null : LatLngBounds(bounds.southWest, bounds.northEast);

    final visibleSignalements = _showSignalements
        ? data.signalements
            .where((s) => _signalementFilter == null || s.statut == _signalementFilter)
            .toList()
        : const <Signalement>[];
    final visibleElements = _showElements
        ? data.elements
            .where((e) => _elementFilter == null || e.statut == _elementFilter)
            .toList()
        : const <ElementRemarquable>[];

    final hovered =
        _hoveredRouteId == null ? null : data.itineraireById(_hoveredRouteId!);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: bounds?.center ?? const LatLng(49.4, 2.8),
            initialZoom: 11,
            initialCameraFit: latLngBounds == null
                ? null
                : CameraFit.bounds(
                    bounds: latLngBounds, padding: const EdgeInsets.all(40)),
            onTap: (tapPos, point) => setState(() {
              _hoveredRouteId = _nearestRouteId(point, routes);
              _selectedSignalement = null;
              _selectedElement = null;
            }),
            onPointerHover: (event, point) {
              final id = _nearestRouteId(point, routes);
              if (id != _hoveredRouteId) setState(() => _hoveredRouteId = id);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.randooise.admin',
            ),
            PolylineLayer(polylines: [
              for (final r in routes)
                for (final line in r.tracks)
                  Polyline(
                    points: line,
                    color: Colors.white,
                    strokeWidth: r.id == _hoveredRouteId ? 8 : 5.5,
                  ),
            ]),
            PolylineLayer(polylines: [
              for (final r in routes)
                for (final line in r.tracks)
                  Polyline(
                    points: line,
                    color: RoutePalette.forId(r.id),
                    strokeWidth: r.id == _hoveredRouteId ? 5 : 3,
                  ),
            ]),
            MarkerLayer(markers: [
              for (final s in visibleSignalements)
                Marker(
                  point: s.position,
                  width: 30,
                  height: 30,
                  child: MapPin(
                    icon: s.categorie.icon,
                    color: s.statut.color,
                    onTap: () => setState(() {
                      _selectedSignalement = s;
                      _selectedElement = null;
                    }),
                  ),
                ),
              for (final e in visibleElements)
                Marker(
                  point: e.position,
                  width: 30,
                  height: 30,
                  child: MapPin(
                    icon: e.categorie.icon,
                    color: e.statut.color,
                    onTap: () => setState(() {
                      _selectedElement = e;
                      _selectedSignalement = null;
                    }),
                  ),
                ),
            ]),
          ],
        ),
        const Positioned(right: 8, bottom: 8, child: MapAttribution()),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: MapFiltersBar(
            showSignalements: _showSignalements,
            showElements: _showElements,
            signalementFilter: _signalementFilter,
            elementFilter: _elementFilter,
            onShowSignalements: (v) => setState(() => _showSignalements = v),
            onShowElements: (v) => setState(() => _showElements = v),
            onSignalementFilter: (v) => setState(() => _signalementFilter = v),
            onElementFilter: (v) => setState(() => _elementFilter = v),
          ),
        ),
        if (hovered != null && _selectedSignalement == null && _selectedElement == null)
          Positioned(
            top: 12,
            left: 12,
            child: IgnorePointer(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(hovered.nom,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        if (_selectedSignalement != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: MapSignalementCard(
              signalement: _selectedSignalement!,
              repo: repo,
              onClose: () => setState(() => _selectedSignalement = null),
            ),
          ),
        if (_selectedElement != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: MapElementCard(
              element: _selectedElement!,
              repo: repo,
              onClose: () => setState(() => _selectedElement = null),
            ),
          ),
      ],
    );
  }
}
