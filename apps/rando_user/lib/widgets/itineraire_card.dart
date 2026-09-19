import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';

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
    final nbSignalements = state.signalementsFor(it.id).length;
    final offline = state.offline.isDownloaded(it.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.nom,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          it.depart ?? it.communesLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                    onPressed: () => state.toggleFavorite(it.id),
                    icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                        color: fav ? RandoColors.danger : scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Stat(icon: Icons.straighten, text: formatDistance(it.lengthM)),
                  _Stat(icon: Icons.schedule, text: formatDurationH(it.dureeH)),
                  if (it.denivelePositif != null)
                    _Stat(icon: Icons.trending_up, text: '${it.denivelePositif!.round()} m D+'),
                  DifficultyChip(it.difficulte, dense: true),
                  if (it.typeItineraire != null)
                    StatusChip(
                        label: it.typeItineraire!,
                        color: RandoColors.inkMuted,
                        icon: Icons.loop,
                        dense: true),
                ],
              ),
              if (distance != null || nbSignalements > 0 || offline) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (distance != null)
                      _Stat(
                        icon: Icons.near_me,
                        text: 'à ${formatDistance(distance)}',
                        color: scheme.primary,
                      ),
                    if (distance != null) const SizedBox(width: 12),
                    if (nbSignalements > 0)
                      _Stat(
                        icon: Icons.report_outlined,
                        text: '$nbSignalements signalement${nbSignalements > 1 ? 's' : ''}',
                        color: SignalementStatut.signale.color,
                      ),
                    const Spacer(),
                    if (offline)
                      Icon(Icons.offline_pin, size: 18, color: scheme.primary),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
