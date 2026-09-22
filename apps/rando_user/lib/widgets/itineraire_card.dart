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

/// Full-width route card used in lists.
class ItineraireCard extends StatelessWidget {
  const ItineraireCard({super.key, required this.itineraire, required this.onTap});

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
    final nb = state.signalementsFor(it.id).length;
    final offline = state.offline.isDownloaded(it.id);
    final color = DifficultyStyle.color(it.difficulte);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBox(icon: difficultyIcon(it.difficulte), color: color, size: 48, radius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.nom, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          it.depart ?? it.communesLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  RoundIconButton(
                    icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                    size: 44,
                    active: fav,
                    onPressed: () => state.toggleFavorite(it.id),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InlineStat(icon: Icons.straighten_rounded, text: formatDistance(it.lengthM), color: scheme.onSurface, bold: true),
                  InlineStat(icon: Icons.schedule_rounded, text: formatDurationH(it.dureeH), color: scheme.onSurface, bold: true),
                  if (it.denivelePositif != null)
                    InlineStat(icon: Icons.trending_up_rounded, text: '${it.denivelePositif!.round()} m', color: scheme.onSurface, bold: true),
                  StatusChip(label: DifficultyStyle.label(it.difficulte), color: color, dense: true),
                ],
              ),
              if (distance != null || nb > 0 || offline) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (distance != null)
                      StatusChip(
                        label: 'à ${formatDistance(distance)}',
                        color: scheme.primary,
                        icon: Icons.near_me_rounded,
                        dense: true,
                      ),
                    if (distance != null && nb > 0) const SizedBox(width: 8),
                    if (nb > 0)
                      StatusChip(
                        label: nb == 1 ? '1 signalement' : '$nb signalements',
                        color: SignalementStatut.signale.color,
                        icon: Icons.campaign_rounded,
                        dense: true,
                      ),
                    const Spacer(),
                    if (offline)
                      Tooltip(
                        message: 'Carte disponible hors ligne',
                        child: Icon(Icons.offline_pin_rounded, size: 20, color: scheme.primary),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact tile for horizontal carousels and grids ("Tes lieux" style).
class ItineraireTile extends StatelessWidget {
  const ItineraireTile({super.key, required this.itineraire, required this.onTap, this.width});

  final Itineraire itineraire;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final it = itineraire;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = DifficultyStyle.color(it.difficulte);
    final distance = state.distanceFromOrigin(it);
    // Relative length bar: share of the longest known route.
    final maxLen = state.itineraires.fold<double>(0, (m, e) => e.lengthM > m ? e.lengthM : m);
    final ratio = maxLen == 0 ? 0.0 : (it.lengthM / maxLen).clamp(0.08, 1.0);

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconBox(icon: difficultyIcon(it.difficulte), color: color, size: 40),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                Text(it.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
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
