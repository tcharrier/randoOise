import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../services/ride_controller.dart';
import '../services/sorties_service.dart';
import '../util/format.dart';
import '../widgets/route_map.dart';
import '../widgets/ui.dart';
import 'element_form_screen.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';

/// GPS navigation along a route, ported from CycloARC: three camera modes
/// (free / follow north-up / heading-up 3D), live trail, stats panel,
/// pause/resume, and an optional save of the outing at the end.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.itineraireId});

  final String itineraireId;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  static const double _headingUpZoom = 17.5;
  static const double _followZoom = 16.5;
  static const double _headingUpOffsetM = 60;
  static const double _followOffsetM = 110;
  static const double _tilt = 55;
  static const EdgeInsets _routePadding = EdgeInsets.fromLTRB(40, 120, 40, 300);

  final _mapKey = GlobalKey<RouteMapState>();
  bool _follow = false;
  bool _headingUp = false;
  bool _mapReady = false;
  bool _showMarkers = true;
  geo.Position? _initialPosition;
  double _lastHeading = 0;
  Timer? _clock;

  RideController get _ride => context.read<AppState>().ride;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _ride.addListener(_onRide);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _ride.isActive) setState(() {});
    });
    _requestInitialPosition();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _clock?.cancel();
    _ride.removeListener(_onRide);
    super.dispose();
  }

  Future<void> _requestInitialPosition() async {
    try {
      final err = await _ride.ensurePermission();
      if (err != null) return;
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      if (!mounted) return;
      setState(() => _initialPosition = pos);
      if (_mapReady && !_ride.isActive) {
        _mapKey.currentState?.moveTo(LatLng(pos.latitude, pos.longitude), 15);
      }
    } catch (_) {}
  }

  void _onRide() {
    if (!mounted) return;
    setState(() {});
    if (_ride.isActive && _ride.currentPosition != null) _animateCameraToUser();
  }

  void _onMapReady(RouteMapState map) {
    _mapReady = true;
    final it = context.read<AppState>().itineraireById(widget.itineraireId);
    if (_ride.isActive && _ride.currentPosition != null && _ride.itineraire?.id == widget.itineraireId) {
      setState(() {
        _headingUp = true;
        _follow = false;
      });
      _animateCameraToUser();
    } else if (it != null) {
      map.fitToRoute(it, padding: _routePadding);
    }
  }

  // ---------------------------------------------------------------- camera

  geo.Position? get _effectivePosition => _ride.currentPosition ?? _initialPosition;

  ml.LatLng _offsetCenter(double lat, double lon, double bearingDeg, double meters) {
    const r = 6371000.0;
    final bearing = bearingDeg * math.pi / 180;
    final lat1 = lat * math.pi / 180;
    final lon1 = lon * math.pi / 180;
    final d = meters / r;
    final lat2 = math.asin(math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(bearing));
    final lon2 = lon1 + math.atan2(math.sin(bearing) * math.sin(d) * math.cos(lat1), math.cos(d) - math.sin(lat1) * math.sin(lat2));
    return ml.LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  void _animateCameraToUser({Duration duration = const Duration(milliseconds: 500)}) {
    final map = _mapKey.currentState;
    final pos = _effectivePosition;
    if (map == null || pos == null) return;
    if (!_follow && !_headingUp) return;
    if (pos.heading >= 0 && pos.speed > 0.6) _lastHeading = pos.heading;
    if (_headingUp) {
      map.animateTo(
        ml.CameraPosition(
          target: _offsetCenter(pos.latitude, pos.longitude, (_lastHeading + 180) % 360, _headingUpOffsetM),
          zoom: _headingUpZoom,
          tilt: _tilt,
          bearing: _lastHeading,
        ),
        duration: duration,
      );
    } else {
      map.animateTo(
        ml.CameraPosition(
          target: _offsetCenter(pos.latitude, pos.longitude, 180, _followOffsetM),
          zoom: _followZoom,
          tilt: 0,
          bearing: 0,
        ),
        duration: duration,
      );
    }
  }

  /// Off → follow (north-up) → heading-up 3D → off.
  void _recenter() {
    setState(() {
      if (!_follow && !_headingUp) {
        _follow = true;
      } else if (_follow) {
        _follow = false;
        _headingUp = true;
      } else {
        _headingUp = false;
      }
    });
    if (_follow || _headingUp) {
      _animateCameraToUser(duration: const Duration(milliseconds: 600));
    } else {
      final cam = _mapKey.currentState?.cameraPosition;
      if (cam != null) {
        _mapKey.currentState?.animateTo(ml.CameraPosition(target: cam.target, zoom: cam.zoom, tilt: 0, bearing: 0),
            duration: const Duration(milliseconds: 400));
      }
    }
  }

  void _fitRoute(Itineraire it) {
    setState(() {
      _follow = false;
      _headingUp = false;
    });
    final map = _mapKey.currentState;
    final cam = map?.cameraPosition;
    if (map == null) return;
    if (cam != null && (cam.tilt > 0 || cam.bearing != 0)) {
      map.animateTo(ml.CameraPosition(target: cam.target, zoom: cam.zoom, tilt: 0, bearing: 0),
          duration: const Duration(milliseconds: 300));
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) map.fitToRoute(it, padding: _routePadding);
      });
    } else {
      map.fitToRoute(it, padding: _routePadding);
    }
  }

  // ------------------------------------------------------------- lifecycle

  Future<void> _start(Itineraire it) async {
    final err = await _ride.start(it);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() {
      _headingUp = true;
      _follow = false;
    });
    _animateCameraToUser(duration: const Duration(milliseconds: 800));
  }

  Future<void> _exit() async {
    if (!_ride.isActive || _ride.itineraire?.id != widget.itineraireId) {
      Navigator.of(context).pop();
      return;
    }
    await _confirmStop();
  }

  Future<void> _confirmStop() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la sortie ?'),
        content: const Text('Tu peux garder cette sortie dans ton historique (sur cet appareil) ou l’abandonner.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'continue'), child: const Text('Continuer')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Sans enregistrer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Terminer')),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'continue') return;
    if (choice == 'discard') {
      _ride.cancel();
      Navigator.of(context).pop();
      return;
    }
    final sortie = _ride.stop();
    if (sortie == null) return;
    await _showCompletion(sortie);
  }

  Future<void> _showCompletion(Sortie sortie) async {
    final note = TextEditingController();
    final state = context.read<AppState>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconBox(icon: sortie.activite.icon, color: sortie.activite.color, size: 72, radius: 24, solid: true),
                const SizedBox(height: 16),
                Text('Bravo !', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(sortie.itineraireNom, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _CompletionStat(value: formatDistance(sortie.distanceKm * 1000), unit: 'parcourus'),
                    _CompletionStat(value: formatDurationSeconds(sortie.durationSeconds), unit: 'de sortie'),
                  ],
                ),
                Row(
                  children: [
                    _CompletionStat(value: formatSpeed(sortie.avgSpeedKmh), unit: 'moyenne'),
                    _CompletionStat(
                      value: sortie.activite == Activite.velo ? formatSpeed(sortie.maxSpeedKmh) : formatPace(sortie.avgSpeedKmh),
                      unit: sortie.activite == Activite.velo ? 'max' : 'allure',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Une note ? (facultatif)', prefixIcon: Icon(Icons.edit_note_rounded)),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ne pas garder')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        );
      },
    );
    if (saved == true) {
      await state.sorties.add(sortie.copyWith(note: note.text.trim()));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved == true ? 'Sortie enregistrée dans ton historique.' : 'Sortie terminée sans enregistrement.'),
    ));
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final it = state.itineraireById(widget.itineraireId);
    if (it == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Itinéraire introuvable.')));
    }
    final theme = Theme.of(context);
    final ride = state.ride;
    final active = ride.isActive && ride.itineraire?.id == it.id;
    final pos = _effectivePosition;
    final userLatLng = pos == null ? null : LatLng(pos.latitude, pos.longitude);
    final offTrack = userLatLng == null ? null : distanceToTracksM(userLatLng, it.tracks);
    final progress = userLatLng == null ? null : progressAlongTracks(userLatLng, it.tracks);
    final topPadding = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          RouteMap(
            key: _mapKey,
            itineraires: [it],
            secondaryItineraires: it.isVelo ? state.veloSecondaires : const [],
            highlightedId: it.id,
            markers: [
              if (_showMarkers && state.showSignalementsOnMap) for (final s in state.signalementsFor(it.id)) signalementMarker(s),
              if (_showMarkers && state.showElementsOnMap) for (final e in state.elementsFor(it.id)) elementMarker(e),
            ],
            userLocation: userLatLng,
            userAccuracyM: pos?.accuracy,
            trail: active ? ride.trail : null,
            fitPadding: _routePadding,
            attribution: false,
            onMapReady: _onMapReady,
            onCameraTrackingDismissed: () {
              if (_follow || _headingUp) setState(() => _follow = _headingUp = false);
            },
            onMarkerTap: (m) {
              final d = m.data;
              if (d is Signalement) showSignalementSheet(context, d);
              if (d is ElementRemarquable) showElementSheet(context, d);
            },
          ),

          // Heading arrow on top of the user dot.
          if (pos != null && _mapReady)
            _UserArrowOverlay(
              mapKey: _mapKey,
              position: userLatLng!,
              heading: pos.heading >= 0 ? pos.heading : _lastHeading,
              headingUp: _headingUp,
              color: it.activite.color,
            ),

          // Top bar
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                RoundIconButton(icon: Icons.close_rounded, label: 'Fermer', elevated: true, onPressed: _exit),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        IconBox(icon: it.activite.icon, color: it.activite.color, size: 36, radius: 12),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                              Text(
                                it.trajetLabel ?? it.communesLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map controls
          Positioned(
            right: 12,
            bottom: active ? 318 : 236,
            child: Column(
              children: [
                RoundIconButton(
                  icon: _headingUp ? Icons.navigation_rounded : Icons.my_location_rounded,
                  label: _headingUp ? 'Vue 3D dans le sens de marche' : (_follow ? 'Suivi de la position' : 'Recentrer sur moi'),
                  active: _follow || _headingUp,
                  elevated: true,
                  onPressed: _recenter,
                ),
                const SizedBox(height: 8),
                RoundIconButton(icon: Icons.fit_screen_rounded, label: 'Voir tout le tracé', elevated: true, onPressed: () => _fitRoute(it)),
                const SizedBox(height: 8),
                RoundIconButton(
                  icon: _showMarkers ? Icons.layers_rounded : Icons.layers_clear_rounded,
                  label: _showMarkers ? 'Masquer signalements et éléments' : 'Afficher signalements et éléments',
                  active: _showMarkers,
                  elevated: true,
                  onPressed: () => setState(() => _showMarkers = !_showMarkers),
                ),
              ],
            ),
          ),

          // Off-track warning
          if (active && offTrack != null && offTrack > 100)
            Positioned(
              left: 12,
              right: 76,
              bottom: 318,
              child: Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Tu es à ${formatDistance(offTrack)} du tracé.',
                            style: TextStyle(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w600)),
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
            child: active
                ? _ActivePanel(
                    it: it,
                    ride: ride,
                    progress: progress,
                    offTrack: offTrack,
                    onPause: () => ride.isPaused ? ride.resume() : ride.pause(),
                    onStop: _confirmStop,
                    onReport: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SignalementFormScreen(itineraire: it, initialPosition: userLatLng),
                    )),
                    onElement: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ElementFormScreen(itineraire: it, initialPosition: userLatLng),
                    )),
                  )
                : _StartPanel(
                    it: it,
                    gpsError: ride.gpsError,
                    hasPosition: pos != null,
                    busy: ride.isActive,
                    onStart: () => _start(it),
                  ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// User arrow overlay (repositioned from the map controller)
// -----------------------------------------------------------------------------

class _UserArrowOverlay extends StatefulWidget {
  const _UserArrowOverlay({
    required this.mapKey,
    required this.position,
    required this.heading,
    required this.headingUp,
    required this.color,
  });

  final GlobalKey<RouteMapState> mapKey;
  final LatLng position;
  final double heading;
  final bool headingUp;
  final Color color;

  @override
  State<_UserArrowOverlay> createState() => _UserArrowOverlayState();
}

class _UserArrowOverlayState extends State<_UserArrowOverlay> {
  Offset? _point;
  ml.MapLibreMapController? _controller;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _attach();
    _update();
  }

  void _attach() {
    final c = widget.mapKey.currentState?.controller;
    if (c != null && c != _controller) {
      _controller?.removeListener(_onCamera);
      _controller = c;
      c.addListener(_onCamera);
    }
  }

  @override
  void didUpdateWidget(covariant _UserArrowOverlay old) {
    super.didUpdateWidget(old);
    _attach();
    _update();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onCamera);
    super.dispose();
  }

  void _onCamera() {
    if (_pending) return;
    _pending = true;
    Future.delayed(const Duration(milliseconds: 40), () {
      _pending = false;
      _update();
    });
  }

  Future<void> _update() async {
    final p = await widget.mapKey.currentState?.toScreen(widget.position);
    if (!mounted || p == null) return;
    setState(() => _point = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _point;
    if (p == null) return const SizedBox.shrink();
    final rotation = widget.headingUp ? 0.0 : widget.heading * math.pi / 180;
    return Positioned(
      left: p.dx - 24,
      top: p.dy - 24,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: rotation,
          child: CustomPaint(size: const Size(48, 48), painter: _ArrowPainter(widget.color)),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // Chevron above the dot, pointing "up".
    final path = Path()
      ..moveTo(c.dx, c.dy - 22)
      ..lineTo(c.dx - 9, c.dy - 8)
      ..lineTo(c.dx, c.dy - 12)
      ..lineTo(c.dx + 9, c.dy - 8)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

// -----------------------------------------------------------------------------
// Panels
// -----------------------------------------------------------------------------

class _StartPanel extends StatelessWidget {
  const _StartPanel({required this.it, required this.onStart, required this.hasPosition, required this.busy, this.gpsError});
  final Itineraire it;
  final VoidCallback onStart;
  final bool hasPosition;
  final bool busy;
  final String? gpsError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _PanelShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBox(icon: it.activite.icon, color: it.activite.color, size: 56, radius: 18, solid: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatDistance(it.lengthM)} · ${formatDurationH(it.dureeH)}', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      hasPosition ? 'Position GPS trouvée. Prêt à partir !' : (gpsError ?? 'Recherche de la position GPS…'),
                      style: theme.textTheme.bodySmall?.copyWith(color: gpsError != null ? scheme.error : null),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onStart,
            style: it.isVelo ? FilledButton.styleFrom(backgroundColor: RandoColors.velo, foregroundColor: Colors.white) : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(busy ? 'Une autre sortie est en cours' : 'Démarrer'),
          ),
        ],
      ),
    );
  }
}

class _ActivePanel extends StatelessWidget {
  const _ActivePanel({
    required this.it,
    required this.ride,
    required this.progress,
    required this.offTrack,
    required this.onPause,
    required this.onStop,
    required this.onReport,
    required this.onElement,
  });

  final Itineraire it;
  final RideController ride;
  final double? progress;
  final double? offTrack;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onReport;
  final VoidCallback onElement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final velo = it.isVelo;
    final accent = velo ? RandoColors.velo : scheme.primary;
    final big = velo ? ride.currentSpeedKmh.toStringAsFixed(0) : (ride.distanceKm).toStringAsFixed(2).replaceAll('.', ',');
    final bigUnit = velo ? 'km/h' : 'km';

    return _PanelShell(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: LinearProgressIndicator(value: progress ?? 0, minHeight: 6, color: accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(big, style: theme.textTheme.displayLarge?.copyWith(fontSize: 52, color: accent, height: 1)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 6),
                  child: Text(bigUnit, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _RideStat(icon: Icons.timer_outlined, label: 'Temps', value: formatElapsed(Duration(seconds: ride.elapsedSeconds))),
                const SizedBox(width: 8),
                if (velo)
                  _RideStat(icon: Icons.straighten_rounded, label: 'Distance', value: formatDistance(ride.distanceKm * 1000))
                else
                  _RideStat(icon: Icons.speed_rounded, label: 'Allure', value: formatPace(ride.avgSpeedKmh)),
                const SizedBox(width: 8),
                _RideStat(icon: Icons.show_chart_rounded, label: 'Moyenne', value: formatSpeed(ride.avgSpeedKmh)),
                const SizedBox(width: 8),
                _RideStat(
                  icon: Icons.route_rounded,
                  label: 'Tracé',
                  value: offTrack == null ? '–' : formatDistance(offTrack!),
                  alert: (offTrack ?? 0) > 100,
                ),
              ],
            ),
          ),
          if (ride.isPaused)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: RandoColors.ochre.withValues(alpha: 0.12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle_filled_rounded, size: 18, color: RandoColors.ochre),
                  SizedBox(width: 8),
                  Text('En pause', style: TextStyle(color: RandoColors.ochre, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ride.isPaused
                      ? FilledButton.icon(
                          onPressed: onPause,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Reprendre'),
                        )
                      : OutlinedButton.icon(
                          onPressed: onPause,
                          icon: const Icon(Icons.pause_rounded),
                          label: const Text('Pause'),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Terminer'),
                  ),
                ),
                const SizedBox(width: 8),
                RoundIconButton(icon: Icons.add_alert_rounded, label: 'Signaler un problème ici', size: 48, onPressed: onReport),
                const SizedBox(width: 6),
                RoundIconButton(icon: Icons.star_rounded, label: 'Proposer un élément remarquable ici', size: 48, onPressed: onElement),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 12)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: SafeArea(top: false, child: Padding(padding: padding, child: child)),
    );
  }
}

class _RideStat extends StatelessWidget {
  const _RideStat({required this.icon, required this.label, required this.value, this.alert = false});
  final IconData icon;
  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: alert ? scheme.errorContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: alert ? scheme.onErrorContainer : scheme.primary),
            const SizedBox(height: 4),
            FittedBox(child: Text(value, style: theme.textTheme.titleSmall)),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  const _CompletionStat({required this.value, required this.unit});
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            FittedBox(child: Text(value, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer))),
            const SizedBox(height: 2),
            Text(unit, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
