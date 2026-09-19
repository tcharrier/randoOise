import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';
import '../widgets/route_map.dart';
import 'element_form_screen.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';

/// Full-screen map following the hiker along the route.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.itineraireId});

  final String itineraireId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _map = MapController();
  StreamSubscription<Position>? _sub;
  Position? _position;
  String? _gpsError;
  bool _follow = true;
  bool _tracking = false;
  DateTime? _startedAt;
  double _walkedM = 0;
  LatLng? _lastPoint;
  final List<LatLng> _trace = [];
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _startGps();
  }

  Future<void> _startGps() async {
    final state = context.read<AppState>();
    final err = await state.location.ensurePermission();
    if (!mounted) return;
    if (err != null) {
      setState(() => _gpsError = err);
      return;
    }
    _sub = state.location.stream().listen((p) {
      if (!mounted) return;
      final point = LatLng(p.latitude, p.longitude);
      setState(() {
        _position = p;
        _gpsError = null;
        if (_tracking) {
          if (_lastPoint != null) {
            final d = haversineM(_lastPoint!, point);
            if (d >= 3 && p.accuracy <= 50) {
              _walkedM += d;
              _lastPoint = point;
              _trace.add(point);
            }
          } else {
            _lastPoint = point;
            _trace.add(point);
          }
        }
      });
      if (_follow) _map.move(point, _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
    }, onError: (e) {
      if (mounted) setState(() => _gpsError = 'GPS indisponible : $e');
    });
  }

  void _toggleTracking() {
    setState(() {
      _tracking = !_tracking;
      if (_tracking) {
        _startedAt = DateTime.now();
        _walkedM = 0;
        _lastPoint = null;
        _trace.clear();
        _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      } else {
        _clock?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final it = state.itineraireById(widget.itineraireId);
    if (it == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Itinéraire introuvable.')));
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pos = _position == null ? null : LatLng(_position!.latitude, _position!.longitude);
    final offTrack = pos == null ? null : distanceToTracksM(pos, it.tracks);
    final progress = pos == null ? null : progressAlongTracks(pos, it.tracks);
    final elapsed = _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);
    final signalements = state.showSignalementsOnMap ? state.signalementsFor(it.id) : <Signalement>[];
    final elements = state.showElementsOnMap ? state.elementsFor(it.id) : <ElementRemarquable>[];

    return Scaffold(
      body: Stack(
        children: [
          RouteMap(
            controller: _map,
            itineraires: [it],
            highlighted: it,
            signalements: signalements,
            elements: elements,
            onSignalementTap: (s) => showSignalementSheet(context, s),
            onElementTap: (e) => showElementSheet(context, e),
            onMapTap: (_) {
              if (_follow) setState(() => _follow = false);
            },
            extraLayers: [
              if (_trace.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: List.of(_trace), color: RandoColors.water, strokeWidth: 3),
                ]),
              if (pos != null) ...userLocationLayers(pos, _position!.accuracy),
            ],
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _RoundButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(it.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Layer toggles
          Positioned(
            top: 64,
            left: 12,
            child: SafeArea(
              child: Wrap(
                spacing: 6,
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.report_outlined, size: 16),
                    label: const Text('Signalements'),
                    selected: state.showSignalementsOnMap,
                    onSelected: (_) => state.toggleShowSignalements(),
                    visualDensity: VisualDensity.compact,
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.star_outline, size: 16),
                    label: const Text('Éléments'),
                    selected: state.showElementsOnMap,
                    onSelected: (_) => state.toggleShowElements(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          // Right buttons
          Positioned(
            right: 12,
            bottom: 200,
            child: Column(
              children: [
                _RoundButton(
                  icon: _follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                  active: _follow,
                  onPressed: () {
                    setState(() => _follow = true);
                    if (pos != null) _map.move(pos, 16);
                  },
                ),
                const SizedBox(height: 8),
                _RoundButton(
                  icon: Icons.fit_screen,
                  onPressed: () {
                    setState(() => _follow = false);
                    _map.fitCamera(CameraFit.bounds(
                      bounds: LatLngBounds(it.bounds.southWest, it.bounds.northEast),
                      padding: const EdgeInsets.all(48),
                    ));
                  },
                ),
              ],
            ),
          ),
          // Off-track warning
          if (offTrack != null && offTrack > 100)
            Positioned(
              left: 12,
              right: 12,
              bottom: 196,
              child: Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Vous êtes à ${formatDistance(offTrack)} du tracé.',
                            style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_gpsError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.location_off, size: 18, color: scheme.error),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_gpsError!, style: TextStyle(color: scheme.error))),
                                TextButton(onPressed: _startGps, child: const Text('Réessayer')),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            _Metric(label: 'Tracé', value: offTrack == null ? '–' : formatDistance(offTrack)),
                            _Metric(label: 'Progression', value: progress == null ? '–' : '${(progress * 100).round()} %'),
                            _Metric(label: 'Parcouru', value: formatDistance(_walkedM)),
                            _Metric(label: 'Durée', value: formatElapsed(elapsed)),
                          ],
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: progress, minHeight: 6),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _toggleTracking,
                                style: _tracking
                                    ? FilledButton.styleFrom(backgroundColor: scheme.error)
                                    : null,
                                icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
                                label: Text(_tracking ? 'Arrêter' : 'Démarrer'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Signaler un problème ici',
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SignalementFormScreen(itineraire: it, initialPosition: pos),
                              )),
                              icon: const Icon(Icons.add_alert_outlined),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Proposer un élément remarquable ici',
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ElementFormScreen(itineraire: it, initialPosition: pos),
                              )),
                              icon: const Icon(Icons.star_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed, this.active = false});
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primaryContainer : scheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: active ? scheme.onPrimaryContainer : scheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}
