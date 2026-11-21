import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../services/sorties_service.dart';
import '../util/format.dart';
import '../widgets/route_map.dart';
import '../widgets/ui.dart';

/// Row for one outing, used on the home page and in the history.
class SortieTile extends StatelessWidget {
  const SortieTile({super.key, required this.sortie});
  final Sortie sortie;

  @override
  Widget build(BuildContext context) {
    final s = sortie;
    return InfoRowCard(
      icon: s.activite.icon,
      color: s.activite.color,
      title: s.itineraireNom,
      subtitle: '${formatDate(s.endedAt, time: false)} · ${formatDistance(s.distanceKm * 1000)} · ${formatDurationSeconds(s.durationSeconds)}',
      chevron: true,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SortieDetailScreen(sortieId: s.id))),
    );
  }
}

/// History of the outings saved on this device.
class SortiesScreen extends StatelessWidget {
  const SortiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sorties = context.watch<AppState>().sorties;
    return AnimatedBuilder(
      animation: sorties,
      builder: (context, _) {
        final list = sorties.all;
        final theme = Theme.of(context);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                PageHeader(
                  title: 'Mes sorties',
                  subtitle: list.isEmpty ? 'Enregistrées sur cet appareil uniquement.' : plural(list.length, 'sortie enregistrée', 'sorties enregistrées'),
                  leading: RoundIconButton(icon: Icons.arrow_back_rounded, label: 'Retour', onPressed: () => Navigator.of(context).pop()),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          title: 'Aucune sortie',
                          subtitle: 'Lance le suivi d’un circuit et enregistre ta sortie à l’arrivée pour la retrouver ici.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                                child: Row(
                                  children: [
                                    _Total(icon: Icons.flag_rounded, value: '${list.length}', label: 'Sorties'),
                                    _Total(icon: Icons.straighten_rounded, value: formatDistance(sorties.totalKm * 1000), label: 'Parcourus'),
                                    _Total(icon: Icons.timer_outlined, value: formatDurationSeconds(sorties.totalSeconds), label: 'Temps total'),
                                    _Total(
                                      icon: Icons.directions_bike_rounded,
                                      value: '${list.where((s) => s.activite == Activite.velo).length}',
                                      label: 'À vélo',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            for (final s in list) ...[
                              SortieTile(sortie: s),
                              const SizedBox(height: 10),
                            ],
                            Text('Les sorties ne quittent jamais ton téléphone.', style: theme.textTheme.bodySmall),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          FittedBox(child: Text(value, style: theme.textTheme.titleMedium)),
          Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// One outing: planned route vs. actual trajectory, stats and note.
class SortieDetailScreen extends StatelessWidget {
  const SortieDetailScreen({super.key, required this.sortieId});
  final String sortieId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AnimatedBuilder(
      animation: state.sorties,
      builder: (context, _) {
        final s = state.sorties.byId(sortieId);
        if (s == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Sortie introuvable.')));
        }
        final it = state.itineraireById(s.itineraireId);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final trajBounds = s.trajectory.isEmpty ? null : GeoBounds.fromPoints(s.trajectory);
        final fit = it == null ? trajBounds : (trajBounds == null ? it.bounds : it.bounds.extend(trajBounds));

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Row(
                  children: [
                    RoundIconButton(icon: Icons.arrow_back_rounded, label: 'Retour', onPressed: () => Navigator.of(context).pop()),
                    const Spacer(),
                    RoundIconButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Supprimer cette sortie',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Supprimer la sortie ?'),
                            content: const Text('Cette sortie sera définitivement retirée de ton historique.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await state.sorties.remove(s.id);
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(s.itineraireNom, style: theme.textTheme.displaySmall),
                const SizedBox(height: 6),
                Text('${s.activite.label} · ${formatDate(s.endedAt)}', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(RandoRadius.card),
                  child: SizedBox(
                    height: 280,
                    child: RouteMap(
                      itineraires: it == null ? const [] : [it],
                      highlightedId: it?.id,
                      actualTrajectory: s.trajectory,
                      initialFit: fit,
                      fitPadding: const EdgeInsets.all(30),
                      showStartMarkers: false,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Legend(color: s.activite == Activite.velo ? RandoColors.trackVelo : RandoColors.track, label: 'Itinéraire prévu'),
                    const SizedBox(width: 16),
                    const _Legend(color: RandoColors.velo, label: 'Trajet réel'),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                    child: Row(
                      children: [
                        _Total(icon: Icons.straighten_rounded, value: formatDistance(s.distanceKm * 1000), label: 'Distance'),
                        _Total(icon: Icons.timer_outlined, value: formatDurationSeconds(s.durationSeconds), label: 'Durée'),
                        _Total(icon: Icons.show_chart_rounded, value: formatSpeed(s.avgSpeedKmh), label: 'Moyenne'),
                        _Total(
                          icon: s.activite == Activite.velo ? Icons.bolt_rounded : Icons.directions_walk_rounded,
                          value: s.activite == Activite.velo ? formatSpeed(s.maxSpeedKmh) : formatPace(s.avgSpeedKmh),
                          label: s.activite == Activite.velo ? 'Max' : 'Allure',
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionHeader('Note'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.edit_note_rounded),
                    title: Text(s.note.isEmpty ? 'Ajouter une note' : s.note),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final ctrl = TextEditingController(text: s.note);
                      final v = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Note'),
                          content: TextField(controller: ctrl, maxLines: 3, autofocus: true, textCapitalization: TextCapitalization.sentences),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Enregistrer')),
                          ],
                        ),
                      );
                      if (v != null) await state.sorties.updateNote(s.id, v.trim());
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text('Départ ${formatDate(s.startedAt)} · ${s.trajectory.length} points GPS', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 5, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
