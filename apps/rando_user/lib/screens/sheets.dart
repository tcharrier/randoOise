import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';
import '../widgets/route_map.dart';
import 'itineraire_detail_screen.dart';

/// Bottom sheet with the details of a report and the "+1" action.
Future<void> showSignalementSheet(BuildContext context, Signalement s) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer<AppState>(
      builder: (ctx, state, _) {
        final live = state.signalements.firstWhere((x) => x.id == s.id, orElse: () => s);
        final it = state.itineraireById(live.itineraireId);
        final mine = live.isAuthor(state.uid);
        final voted = live.hasVoted(state.uid);
        final theme = Theme.of(ctx);
        return _SheetBody(
          title: live.categorie.label,
          subtitle: live.itineraireNom,
          icon: live.categorie.icon,
          color: live.statut.color,
          map: RouteMap(
            itineraires: it == null ? const [] : [it],
            highlightedId: it?.id,
            markers: [signalementMarker(live)],
            initialCenter: live.position,
            initialZoom: 14.5,
            interactive: false,
            showStartMarkers: false,
            attribution: false,
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  label: live.statut == SignalementStatut.valide ? 'Validé' : live.statut.label,
                  color: live.statut.color,
                  icon: live.statut == SignalementStatut.valide ? Icons.verified_rounded : Icons.schedule_rounded,
                ),
                Text(formatDate(live.createdAt), style: theme.textTheme.bodySmall),
              ],
            ),
            if (live.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(live.description, style: theme.textTheme.bodyLarge),
            ],
            if (live.commentaireAdmin != null && live.commentaireAdmin!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Réponse du modérateur', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(live.commentaireAdmin!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: voted || mine
                        ? null
                        : () async {
                            final ok = await state.vote(live);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(ok ? 'Merci, ton +1 a été pris en compte.' : (state.authError ?? 'Impossible de voter pour le moment.')),
                            ));
                          },
                    icon: Icon(voted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined),
                    label: Text(mine ? 'Ton signalement (+${live.votes})' : (voted ? 'Confirmé (+${live.votes})' : 'Je confirme (+${live.votes})')),
                  ),
                ),
                if (it != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ItineraireDetailScreen(itineraireId: it.id),
                      ));
                    },
                    child: const Text('Circuit'),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showElementSheet(BuildContext context, ElementRemarquable e) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer<AppState>(
      builder: (ctx, state, _) {
        final it = state.itineraireById(e.itineraireId);
        final theme = Theme.of(ctx);
        final color = e.isValide ? RandoColors.blue : e.statut.color;
        return _SheetBody(
          title: e.titre,
          subtitle: '${e.categorie.label} · ${e.itineraireNom}',
          icon: e.categorie.icon,
          color: color,
          map: RouteMap(
            itineraires: it == null ? const [] : [it],
            highlightedId: it?.id,
            markers: [elementMarker(e)],
            initialCenter: e.position,
            initialZoom: 14.5,
            interactive: false,
            showStartMarkers: false,
            attribution: false,
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  label: e.isValide ? 'Validé' : e.statut.label,
                  color: color,
                  icon: e.isValide ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                ),
                Text(formatDate(e.createdAt), style: theme.textTheme.bodySmall),
              ],
            ),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(e.description, style: theme.textTheme.bodyLarge),
            ],
          ],
        );
      },
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.map,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget map;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(height: 160, child: map),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
