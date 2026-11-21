import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';
import '../widgets/itineraire_card.dart';
import '../widgets/route_map.dart';
import '../widgets/signalement_tile.dart';
import '../widgets/ui.dart';
import '../widgets/weather_widgets.dart';
import 'carte_screen.dart';
import 'circuits_screen.dart';
import 'favoris_screen.dart';
import 'itineraire_detail_screen.dart';
import 'navigation_screen.dart';
import 'profil_screen.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';
import 'signalements_screen.dart';
import 'sorties_screen.dart';

/// Single main page: greeting, random discovery (hike or ride), weather,
/// quick access tiles (map, reports, profile), nearby routes, favorites,
/// latest outings and reports.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Itineraire it) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItineraireDetailScreen(itineraireId: it.id)),
      );

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final name = state.displayName.isEmpty ? 'Randonneur' : state.displayName;
    final discovery = state.discovery;
    final nearest = state.nearest(limit: 6).where((it) => it.id != discovery?.id).toList();
    final favs = state.favoriteItineraires;
    final recent = state.recentSignalements(limit: 3);
    final pending = state.signalements.where((s) => s.statut == SignalementStatut.signale).length;
    final scale = MediaQuery.textScalerOf(context);
    final tileH = scale.scale(104);
    final topH = scale.scale(52); // date/time + weather: half a tile
    final heroH = scale.scale(312);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Header
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Ouvrir le profil',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () => _push(context, const ProfilScreen()),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InitialsAvatar(name: name),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bonjour', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                                Text(name, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    label: dark ? 'Passer en mode clair' : 'Passer en mode sombre',
                    onPressed: () => state.toggleTheme(theme.brightness),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.search_rounded,
                    label: 'Rechercher un circuit',
                    onPressed: () => _push(context, const CircuitsScreen(autofocusSearch: true)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Prêt pour une balade ?', style: theme.textTheme.displayMedium),
              const SizedBox(height: 16),

              // Row 1: date / time + weather (half width each, half height)
              SizedBox(
                height: topH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(child: _DateTimeTile()),
                    SizedBox(width: 12),
                    Expanded(child: WeatherTile(compact: true)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Outing in progress
              AnimatedBuilder(
                animation: state.ride,
                builder: (context, _) {
                  final ride = state.ride;
                  final it = ride.itineraire;
                  if (!ride.isActive || it == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InfoRowCard(
                      icon: it.activite.icon,
                      color: it.activite.color,
                      title: ride.isPaused ? 'Sortie en pause' : 'Sortie en cours',
                      subtitle:
                          '${it.titre} · ${formatElapsed(Duration(seconds: ride.elapsedSeconds))} · ${formatDistance(ride.distanceKm * 1000)}',
                      chevron: true,
                      onTap: () => _push(context, NavigationScreen(itineraireId: it.id)),
                    ),
                  );
                },
              ),

              // Row 2: random discovery (fixed height)
              if (!state.itinerairesLoaded)
                _HeroSkeleton(height: heroH)
              else if (discovery == null)
                _EmptyHero(state: state)
              else
                RepaintBoundary(
                  child: _HeroCard(
                    itineraire: discovery,
                    height: heroH,
                    onOpen: () => _open(context, discovery),
                    onShuffle: state.shuffleDiscovery,
                  ),
                ),

              if (state.itinerairesFromCache && state.itinerairesLoaded)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Hors ligne : données enregistrées sur l’appareil', style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),

              // Row 3: quick access: big map tile (left) + reports / profile (right)
              const SizedBox(height: 12),
              _QuickAccess(
                tileHeight: tileH,
                map: RepaintBoundary(
                  child: _MapTile(
                    itineraires: state.itineraires,
                    secondary: state.veloSecondaires,
                    subtitle: '${plural(state.countFor(Activite.pied), 'rando')} · ${plural(state.countFor(Activite.velo), 'piste')}',
                    onTap: () => _push(context, const CarteScreen()),
                  ),
                ),
                reports: _QuickTile(
                  icon: Icons.campaign_rounded,
                  color: SignalementStatut.signale.color,
                  title: 'Signalements',
                  subtitle: pending == 0
                      ? (state.signalements.isEmpty ? 'Aucun problème' : 'Tout est traité')
                      : '${plural(pending, 'problème')} en attente',
                  badge: pending,
                  onTap: () => _push(context, const SignalementsScreen()),
                ),
                profile: _QuickTile(
                  icon: Icons.person_rounded,
                  color: RandoColors.blue,
                  title: 'Profil',
                  subtitle: favs.isEmpty ? 'Favoris, sorties' : plural(favs.length, 'favori'),
                  onTap: () => _push(context, const ProfilScreen()),
                ),
              ),

              // Row 4: favorites
              SectionHeader(
                'Tes favoris',
                actionLabel: favs.isEmpty ? null : 'Voir tout',
                onAction: () => _push(context, const FavorisScreen()),
              ),
              if (favs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const IconBox(icon: Icons.favorite_border_rounded, color: RandoColors.red, size: 46),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Touche le cœur d’un circuit pour le retrouver ici, même sans réseau.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: scale.scale(168),
                  ),
                  itemCount: favs.length.clamp(0, 4),
                  itemBuilder: (_, i) => ItineraireTile(itineraire: favs[i], onTap: () => _open(context, favs[i])),
                ),

              // Row 5: nearby
              if (nearest.isNotEmpty || state.activiteFilter != null) ...[
                SectionHeader(
                  state.origin == null ? 'Circuits à découvrir' : 'Circuits près de toi',
                  actionLabel: 'Voir tout',
                  onAction: () => _push(context, const CircuitsScreen()),
                ),
                SourceFilterChips(state: state),
                const SizedBox(height: 10),
                if (nearest.isEmpty)
                  Text('Aucun circuit pour ce filtre.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
                else
                  SizedBox(
                    height: scale.scale(168),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: nearest.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => ItineraireTile(
                        itineraire: nearest[i],
                        width: 196,
                        onTap: () => _open(context, nearest[i]),
                      ),
                    ),
                  ),
              ],

              // Last outings
              AnimatedBuilder(
                animation: state.sorties,
                builder: (context, _) {
                  final list = state.sorties.all.take(2).toList();
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        'Tes dernières sorties',
                        actionLabel: 'Voir tout',
                        onAction: () => _push(context, const SortiesScreen()),
                      ),
                      for (final s in list) ...[
                        SortieTile(sortie: s),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),

              // Recent reports
              SectionHeader(
                'Derniers signalements',
                actionLabel: recent.isEmpty ? null : 'Voir tout',
                onAction: () => _push(context, const SignalementsScreen()),
              ),
              if (recent.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const IconBox(icon: Icons.check_circle_outline_rounded, color: RandoColors.green, size: 46),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Aucun problème signalé pour le moment. Bonne balade !',
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final s in recent) ...[
                  SignalementTile(signalement: s, compact: true, onTap: () => showSignalementSheet(context, s)),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: state.itineraires.isEmpty ? null : () => _push(context, const SignalementFormScreen()),
                icon: const Icon(Icons.add_alert_rounded),
                label: const Text('Signaler un problème'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Quick access block: a big map tile (5/8 of the width) on the left, two
/// compact tiles (3/8) stacked on the right.
class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.tileHeight, required this.map, required this.reports, required this.profile});
  final double tileHeight;
  final Widget map;
  final Widget reports;
  final Widget profile;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    return SizedBox(
      height: tileHeight * 2 + gap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: map),
          const SizedBox(width: gap),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(child: reports),
                const SizedBox(height: gap),
                Expanded(child: profile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Badge.count(count: badge, isLabelVisible: badge > 0, child: IconBox(icon: icon, color: color, size: 32, radius: 10)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big tile with a live preview of every route; opens the full map.
class _MapTile extends StatelessWidget {
  const _MapTile({required this.itineraires, required this.secondary, required this.subtitle, required this.onTap});
  final List<Itineraire> itineraires;
  final List<Itineraire> secondary;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Ouvrir la carte des circuits',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (itineraires.isEmpty)
              Container(color: scheme.surfaceContainer)
            else
              RouteMap(
                itineraires: itineraires,
                secondaryItineraires: secondary,
                interactive: false,
                showStartMarkers: false,
                attribution: false,
                fitPadding: const EdgeInsets.all(14),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [scheme.surface.withValues(alpha: 0), scheme.surface.withValues(alpha: 0.96)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Carte', style: theme.textTheme.titleLarge),
                    Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 12,
              top: 12,
              child: IconBox(icon: Icons.map_rounded, color: RandoColors.green, size: 40, solid: true),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date and live clock tile (updates every 30 s).
class _DateTimeTile extends StatefulWidget {
  const _DateTimeTile();

  @override
  State<_DateTimeTile> createState() => _DateTimeTileState();
}

class _DateTimeTileState extends State<_DateTimeTile> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          child: Row(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$hh:$mm',
                  style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatShortDate(_now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(child: Text('Compiègne', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Discovery card with a fixed height. Hikes keep the green contour-line
/// background; rides get a blue "wheel" background and use the official plan
/// colour of the line as accent.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.itineraire, required this.height, required this.onOpen, required this.onShuffle});
  final Itineraire itineraire;
  final double height;
  final VoidCallback onOpen;
  final VoidCallback onShuffle;

  static const _radius = 18.0;

  /// Keeps a plan colour readable on the card background.
  static Color _readable(Color c, bool dark) {
    final hsl = HSLColor.fromColor(c);
    if (dark && hsl.lightness < 0.62) return hsl.withLightness(0.7).toColor();
    if (!dark && hsl.lightness > 0.45) return hsl.withLightness(0.36).toColor();
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final it = itineraire;
    final velo = it.isVelo;
    final distance = state.distanceFromOrigin(it);
    final fav = state.isFavorite(it.id);
    final plan = planAccent(it);
    final accent = plan != null
        ? _readable(plan, dark)
        : velo
            ? (dark ? const Color(0xFF7FD3E6) : RandoColors.veloDeep)
            : scheme.primary;
    final gradient = velo
        ? (dark ? [const Color(0xFF10333D), const Color(0xFF0B2630)] : [const Color(0xFFD6EEF5), const Color(0xFFBFE0EC)])
        : (dark ? [const Color(0xFF16352A), const Color(0xFF0F2A1F)] : [const Color(0xFFDDEFE3), const Color(0xFFC9E4D3)]);
    final patternColor =
        (velo ? (dark ? const Color(0xFF7FD3E6) : RandoColors.velo) : (dark ? RandoColors.nightGreen : RandoColors.green))
            .withValues(alpha: 0.18);
    final Color? buttonColor = plan ?? (velo ? (dark ? const Color(0xFF1E5A68) : RandoColors.velo) : null);
    final buttonFg = (buttonColor != null && buttonColor.computeLuminance() > 0.6) ? Colors.black87 : Colors.white;
    final subtitle = velo ? it.trajetLabel : it.communesLabel;

    final pills = <({IconData icon, String label, String value})>[
      (icon: Icons.straighten_rounded, label: 'Distance', value: formatDistance(it.lengthM)),
      (icon: Icons.schedule_rounded, label: 'Durée', value: formatDurationH(it.dureeH)),
      if (velo)
        (icon: Icons.check_circle_outline_rounded, label: 'Réseau', value: it.statutReseau?.label ?? 'Piste')
      else
        (icon: difficultyIcon(it.difficulte), label: 'Niveau', value: DifficultyStyle.label(it.difficulte)),
    ];

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'À découvrir · ${it.activite.label.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: accent),
                ),
              ),
              RoundIconButton(icon: Icons.shuffle_rounded, label: 'Découvrir un autre circuit', size: 40, onPressed: onShuffle),
              const SizedBox(width: 6),
              RoundIconButton(
                icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                size: 40,
                active: fav,
                onPressed: () => state.toggleFavorite(it.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Title block: takes the free space, at most 2 lines + 1 line.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.titre, style: theme.textTheme.displaySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          // Distance from the user: slot always reserved.
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: distance != null
                  ? Text(
                      'à ${formatDistance(distance)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(color: accent),
                    )
                  : Text(
                      'Distance inconnue · active le GPS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Stat pills: one row, never wraps or overflows.
          Row(
            children: [
              for (var i = 0; i < pills.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Flexible(
                  flex: math.max(3, pills[i].value.length + 4),
                  child: StatPill(icon: pills[i].icon, label: pills[i].label, value: pills[i].value, onDark: dark, dense: true),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: buttonColor,
              foregroundColor: buttonColor == null ? null : buttonFg,
            ),
            child: Row(
              children: [
                Icon(it.activite.icon, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('Voir le circuit', maxLines: 1, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: 'Circuit ${it.titre}, ${it.activite.label}',
      child: SizedBox(
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(_radius),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: velo ? WheelBackground(color: patternColor, child: body) : TopoBackground(color: patternColor, child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative bicycle-wheel pattern for cycling discovery cards.
class WheelBackground extends StatelessWidget {
  const WheelBackground({super.key, required this.color, this.child});
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WheelPainter(color), child: child);
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final c = Offset(size.width * 0.86, size.height * 0.28);
    for (final r in [46.0, 92.0, 150.0]) {
      canvas.drawCircle(c, r, paint);
    }
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * 14, c + Offset(math.cos(a), math.sin(a)) * 150, paint);
    }
    final c2 = Offset(size.width * 0.12, size.height * 0.95);
    for (final r in [30.0, 62.0]) {
      canvas.drawCircle(c2, r, paint);
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.color != color;
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aucun circuit disponible', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              state.loadError == null
                  ? 'Connecte-toi à internet une première fois pour télécharger les circuits.'
                  : 'Impossible de charger les circuits : ${state.loadError}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}
