import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';
import 'ui.dart';

/// A report in a list, with the "+1" button and its validation state.
class SignalementTile extends StatelessWidget {
  const SignalementTile({
    super.key,
    required this.signalement,
    this.showItineraire = true,
    this.onTap,
    this.compact = false,
  });

  final Signalement signalement;
  final bool showItineraire;
  final VoidCallback? onTap;
  final bool compact;

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
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBox(icon: s.categorie.icon, color: s.statut.color, size: 46, radius: 15),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.categorie.label, style: theme.textTheme.titleMedium),
                    if (showItineraire)
                      Text(s.itineraireNom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                    if (s.description.isNotEmpty && !compact) ...[
                      const SizedBox(height: 4),
                      Text(s.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: s.statut == SignalementStatut.valide ? "Validé par l'ARC" : s.statut.label,
                          color: s.statut.color,
                          icon: s.statut == SignalementStatut.valide
                              ? Icons.verified_rounded
                              : (s.statut == SignalementStatut.enCours ? Icons.construction_rounded : Icons.schedule_rounded),
                          dense: true,
                        ),
                        Text(formatRelative(s.createdAt), style: theme.textTheme.labelSmall),
                        if (s.isAuthor(state.uid)) Text('Par vous', style: theme.textTheme.labelSmall),
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
    return Semantics(
      button: true,
      label: voted ? 'Vous avez confirmé ce signalement, $count confirmations' : 'Confirmer ce signalement, $count confirmations',
      child: Material(
        color: voted ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(voted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                    size: 20, color: voted ? scheme.onPrimaryContainer : scheme.onSurface),
                const SizedBox(height: 2),
                Text('+$count',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: voted ? scheme.onPrimaryContainer : scheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
