import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';

/// A report in a list, with the "+1" button and its validation state.
class SignalementTile extends StatelessWidget {
  const SignalementTile({
    super.key,
    required this.signalement,
    this.showItineraire = true,
    this.onTap,
  });

  final Signalement signalement;
  final bool showItineraire;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = signalement;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final voted = s.hasVoted(state.uid);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.statut.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(s.categorie.icon, color: s.statut.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.categorie.label,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (showItineraire)
                      Text(s.itineraireNom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
                    if (s.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(s.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: s.statut == SignalementStatut.valide
                              ? "Validé par l'ARC"
                              : s.statut.label,
                          color: s.statut.color,
                          icon: s.statut == SignalementStatut.valide
                              ? Icons.verified
                              : (s.statut == SignalementStatut.enCours
                                  ? Icons.construction
                                  : Icons.schedule),
                          dense: true,
                        ),
                        Text(formatDate(s.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                        if (s.isAuthor(state.uid))
                          Text('Votre signalement',
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _VoteButton(
                count: s.votes,
                voted: voted,
                onPressed: voted ? null : () => _vote(context, state, s),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _vote(BuildContext context, AppState state, Signalement s) async {
    final ok = await state.vote(s);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Merci, votre +1 a été pris en compte.'
          : 'Impossible de voter pour le moment (connexion requise la première fois).'),
    ));
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.count, required this.voted, this.onPressed});
  final int count;
  final bool voted;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: voted ? scheme.primaryContainer : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(voted ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 20, color: voted ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
              const SizedBox(height: 2),
              Text('+$count',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: voted ? scheme.onPrimaryContainer : scheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
