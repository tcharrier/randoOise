import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import 'route_map.dart';

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
  final _map = MapController();
  bool _locating = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    final state = context.read<AppState>();
    final p = await state.location.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Position GPS indisponible. Touchez la carte pour placer le point.'),
      ));
      return;
    }
    widget.onChanged(p);
    _map.move(p, 16);
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
                  controller: _map,
                  itineraires: it == null ? const [] : [it],
                  highlighted: it,
                  showStartMarkers: false,
                  pickedPoint: v,
                  initialCenter: v,
                  initialZoom: 15,
                  onMapTap: widget.onChanged,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: scheme.surface,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: _locating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            tooltip: 'Utiliser ma position GPS',
                            icon: const Icon(Icons.my_location),
                            onPressed: _useGps,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          v == null
              ? 'Touchez la carte pour placer le point, ou utilisez le GPS.'
              : 'Point placé${offTrack == null ? '' : ' à ${formatDistance(offTrack)} du tracé'}.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
