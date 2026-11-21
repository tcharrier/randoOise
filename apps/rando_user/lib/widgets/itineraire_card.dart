import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import 'ui.dart';

IconData difficultyIcon(String? d) {
  final s = (d ?? '').toLowerCase();
  if (s.contains('difficile')) return Icons.terrain_rounded;
  if (s.contains('moyen')) return Icons.landscape_rounded;
  if (s.contains('facile')) return Icons.park_rounded;
  return Icons.hiking_rounded;
}

/// Icon and colour identifying a route at a glance.
IconData routeIcon(Itineraire it) => it.isVelo ? Icons.directions_bike_rounded : difficultyIcon(it.difficulte);
/// Plan colour usable as an interface accent: grey plan colours (routes 17,
/// 18, 20) stay grey on the map but would look disabled on buttons.
Color? planAccent(Itineraire it) {
  if (!it.isVelo || it.couleur == null) return null;
  final color = Color(it.couleur!);
  final hsl = HSLColor.fromColor(color);
  return hsl.saturation < 0.18 ? null : color;
}

Color routeColor(Itineraire it) =>
    it.isVelo ? (planAccent(it) ?? RandoColors.velo) : DifficultyStyle.color(it.difficulte);

bool _hasDifficulty(Itineraire it) => (it.difficulte ?? '').trim().isNotEmpty;

/// Icon box, or a coloured disc with the plan number for numbered cycling routes.
class RouteBadge extends StatelessWidget {
  const RouteBadge(this.it, {super.key, this.size = 48});
  final Itineraire it;
  final double size;

  @override
  Widget build(BuildContext context) {
    final num = it.numero;
    if (it.isVelo && it.couleur != null) {
      final c = Color(it.couleur!);
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: num == null || num.isEmpty
            ? Icon(Icons.directions_bike_rounded, color: Colors.white, size: size * 0.52)
            : Padding(
                padding: const EdgeInsets.all(4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    num,
                    style: TextStyle(
                      fontFamily: kRandoDisplayFont,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: size * 0.4,
                    ),
                  ),
                ),
              ),
      );
    }
    return IconBox(icon: routeIcon(it), color: routeColor(it), size: size, radius: size / 3);
  }
}

/// The two data sources as filter chips: « Pistes ARC » (velo) and « Chemins rando » (pied).
/// Both selected = no filter; never allows an empty selection.
class SourceFilterChips extends StatelessWidget {
  const SourceFilterChips({super.key, required this.state, this.onChanged});
  final AppState state;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final f = state.activiteFilter;
    bool on(Activite a) => f == null || f == a;
    void toggle(Activite a) {
      final other = a == Activite.velo ? Activite.pied : Activite.velo;
      // Deselecting keeps the other one; selecting again restores both.
      if (on(a) && f != null) return; // never allow an empty selection
      state.setActiviteFilter(f == null ? other : null);
      onChanged?.call();
    }

    final scheme = Theme.of(context).colorScheme;
    Widget chip(Activite a, String label) => FilterChip(
          avatar: Icon(a.icon, size: 16, color: on(a) ? scheme.surface : scheme.onSurface),
          label: Text(label),
          labelStyle: TextStyle(color: on(a) ? scheme.surface : scheme.onSurface, fontWeight: FontWeight.w600),
          selected: on(a),
          showCheckmark: false,
          backgroundColor: scheme.surface,
          selectedColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          visualDensity: VisualDensity.compact,
          onSelected: (_) => toggle(a),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [chip(Activite.velo, 'Pistes ARC'), chip(Activite.pied, 'Chemins rando')],
    );
  }
}

/// Small chip telling whether a route is a hike or a ride.
class ActiviteChip extends StatelessWidget {
  const ActiviteChip(this.activite, {super.key, this.dense = true});
  final Activite activite;
  final bool dense;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: activite.label, color: activite.color, icon: activite.icon, dense: dense);
}

/// The second badge: difficulty for hikes (nothing if unknown), lane status for rides.
class RouteStatusChip extends StatelessWidget {
  const RouteStatusChip(this.it, {super.key, this.dense = true});
  final Itineraire it;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (it.isVelo) {
      final s = it.statutReseau;
      if (s == null) return const SizedBox.shrink();
      return StatusChip(
        label: s.label,
        color: s.color,
        icon: s == StatutReseau.enService ? Icons.check_circle_outline_rounded : Icons.construction_rounded,
        dense: dense,
      );
    }
    if (!_hasDifficulty(it)) return const SizedBox.shrink();
    return StatusChip(label: DifficultyStyle.label(it.difficulte), color: DifficultyStyle.color(it.difficulte), dense: dense);
  }
}

/// Single-line stat cell (icon + ellipsised text).
class _StatCell extends StatelessWidget {
  const _StatCell(this.icon, this.text, {this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: c, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

String _subtitle(Itineraire it) {
  final s = it.isVelo ? (it.trajetLabel ?? it.communesLabel) : (it.depart ?? it.communesLabel);
  return s.trim().isEmpty ? '—' : s;
}

/// Full-width route card used in lists. Fixed height whatever the data.
class ItineraireCard extends StatelessWidget {
  const ItineraireCard({super.key, required this.itineraire, required this.onTap});

  /// Base height (logical px), scaled with the text scale factor.
  static const double baseHeight = 148;

  final Itineraire itineraire;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final it = itineraire;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final distance = state.distanceFromOrigin(it);
    final fav = state.isFavorite(it.id);
    final offline = it.embedded || state.offline.isSaved(it.id);
    final height = MediaQuery.textScalerOf(context).scale(baseHeight);
    final statut = it.statutReseau;

    final third = it.isVelo
        ? _StatCell(Icons.traffic_rounded, statut?.label ?? '—', color: statut?.color)
        : _StatCell(Icons.trending_up_rounded, it.denivelePositif != null ? '${it.denivelePositif!.round()} m' : '—');

    return SizedBox(
      height: height,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RouteBadge(it, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(it.titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(_subtitle(it), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    RoundIconButton(
                      icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                      size: 40,
                      active: fav,
                      onPressed: () => state.toggleFavorite(it.id),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      Expanded(child: _StatCell(Icons.straighten_rounded, formatDistance(it.lengthM))),
                      Expanded(child: _StatCell(Icons.schedule_rounded, formatDurationH(it.dureeH))),
                      Expanded(child: third),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      _fit(ActiviteChip(it.activite)),
                      if (it.isVelo ? statut != null : _hasDifficulty(it)) ...[
                        const SizedBox(width: 6),
                        _fit(RouteStatusChip(it)),
                      ],
                      if (distance != null) ...[
                        const SizedBox(width: 6),
                        _fit(StatusChip(label: 'à ${formatDistance(distance)}', color: scheme.primary, icon: Icons.near_me_rounded, dense: true)),
                      ],
                      const Spacer(),
                      if (offline)
                        Tooltip(
                          message: it.embedded ? 'Tracé intégré à l’app' : 'Carte disponible hors ligne',
                          child: Icon(Icons.offline_pin_rounded, size: 20, color: scheme.primary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _fit(Widget w) => Flexible(
        child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: w),
      );
}

/// Compact tile for horizontal carousels and grids. Fixed height.
class ItineraireTile extends StatelessWidget {
  const ItineraireTile({super.key, required this.itineraire, required this.onTap, this.width});

  static const double baseHeight = 160;

  final Itineraire itineraire;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final it = itineraire;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = routeColor(it);
    final distance = state.distanceFromOrigin(it);
    // Relative length bar: share of the longest known route of the same activity.
    final maxLen = state.itineraires
        .where((e) => e.activite == it.activite)
        .fold<double>(0, (m, e) => e.lengthM > m ? e.lengthM : m);
    final ratio = maxLen == 0 ? 0.0 : (it.lengthM / maxLen).clamp(0.08, 1.0);

    return SizedBox(
      width: width,
      height: MediaQuery.textScalerOf(context).scale(baseHeight),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RouteBadge(it, size: 40),
                    const Spacer(),
                    Icon(it.activite.icon, size: 18, color: it.activite.color),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
                const Spacer(),
                Text(it.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${formatDistance(it.lengthM)} · ${formatDurationH(it.dureeH)}'
                  '${distance != null ? ' · à ${formatDistance(distance)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: ratio, minHeight: 6, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
