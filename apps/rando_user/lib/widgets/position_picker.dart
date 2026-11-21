import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import 'route_map.dart';
import 'ui.dart';

/// Small map used by the forms to pick the location of a report / point of
/// interest: tap to place the marker, or use the GPS button.
class PositionPicker extends StatefulWidget {
  const PositionPicker({
    super.key,
    required this.itineraire,
    required this.value,
    required this.onChanged,
  });

  final Itineraire? itineraire;
  final LatLng? value;
  final ValueChanged<LatLng> onChanged;

  @override
  State<PositionPicker> createState() => _PositionPickerState();
}

class _PositionPickerState extends State<PositionPicker> {
  final _mapKey = GlobalKey<RouteMapState>();
  bool _locating = false;

  Future<void> _useGps() async {
    setState(() => _locating = true);
    final state = context.read<AppState>();
    final p = await state.location.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Position GPS indisponible. Touche la carte pour placer le point.'),
      ));
      return;
    }
    widget.onChanged(p);
    _mapKey.currentState?.moveTo(p, 16);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.itineraire;
    final scheme = Theme.of(context).colorScheme;
    final v = widget.value;
    final offTrack = (v != null && it != null) ? distanceToTracksM(v, it.tracks) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 240,
            child: Stack(
              children: [
                RouteMap(
                  key: _mapKey,
                  itineraires: it == null ? const [] : [it],
                  highlightedId: it?.id,
                  showStartMarkers: false,
                  markers: [
                    if (v != null)
                      MapMarker(id: 'picked', position: v, color: RandoColors.red, icon: Icons.place_rounded, size: 36),
                  ],
                  initialCenter: v,
                  initialZoom: 15,
                  fitPadding: const EdgeInsets.all(30),
                  onMapTap: widget.onChanged,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _locating
                      ? Material(
                          color: scheme.surface,
                          shape: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        )
                      : RoundIconButton(
                          icon: Icons.my_location_rounded,
                          label: 'Utiliser ma position GPS',
                          size: 48,
                          elevated: true,
                          onPressed: _useGps,
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          v == null
              ? 'Touche la carte pour placer le point, ou utilise le GPS.'
              : 'Point placé${offTrack == null ? '' : ' à ${formatDistance(offTrack)} du tracé'}.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
