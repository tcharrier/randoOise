import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rando_core/rando_core.dart';

import 'map_pin.dart';

/// Map of a single route with its start / parking / reports / points of
/// interest, used in the itinéraire detail panel.
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.itineraire,
    this.signalements = const [],
    this.elements = const [],
    this.height = 320,
  });

  final Itineraire itineraire;
  final List<Signalement> signalements;
  final List<ElementRemarquable> elements;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bounds = itineraire.bounds.pad(120);
    final latLngBounds = LatLngBounds(bounds.southWest, bounds.northEast);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: latLngBounds,
                  padding: const EdgeInsets.all(24),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.scrollWheelZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'fr.randooise.admin',
                ),
                PolylineLayer(polylines: [
                  for (final line in itineraire.tracks)
                    Polyline(
                      points: line,
                      color: RandoColors.trackHalo,
                      strokeWidth: 7,
                    ),
                ]),
                PolylineLayer(polylines: [
                  for (final line in itineraire.tracks)
                    Polyline(
                      points: line,
                      color: RandoColors.track,
                      strokeWidth: 4,
                    ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: itineraire.start,
                    width: 34,
                    height: 34,
                    child: const MapPin(icon: Icons.flag, color: RandoColors.forest),
                  ),
                  if (itineraire.parking != null)
                    Marker(
                      point: itineraire.parking!,
                      width: 30,
                      height: 30,
                      child: const MapPin(
                          icon: Icons.local_parking, color: RandoColors.water),
                    ),
                  for (final s in signalements)
                    Marker(
                      point: s.position,
                      width: 28,
                      height: 28,
                      child: MapPin(icon: s.categorie.icon, color: s.statut.color),
                    ),
                  for (final e in elements)
                    Marker(
                      point: e.position,
                      width: 28,
                      height: 28,
                      child: MapPin(icon: e.categorie.icon, color: e.statut.color),
                    ),
                ]),
              ],
            ),
            const Positioned(right: 4, bottom: 2, child: MapAttribution()),
          ],
        ),
      ),
    );
  }
}
