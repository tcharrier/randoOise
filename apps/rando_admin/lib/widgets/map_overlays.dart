import 'package:flutter/material.dart';
import 'package:rando_core/rando_core.dart';

import '../utils/date_format.dart';
import 'element_actions.dart';
import 'signalement_actions.dart';

/// Top overlay letting the user toggle the reports / points of interest
/// layers and filter each one by status.
class MapFiltersBar extends StatelessWidget {
  const MapFiltersBar({
    super.key,
    required this.showSignalements,
    required this.showElements,
    required this.signalementFilter,
    required this.elementFilter,
    required this.onShowSignalements,
    required this.onShowElements,
    required this.onSignalementFilter,
    required this.onElementFilter,
  });

  final bool showSignalements;
  final bool showElements;
  final SignalementStatut? signalementFilter;
  final ElementStatut? elementFilter;
  final ValueChanged<bool> onShowSignalements;
  final ValueChanged<bool> onShowElements;
  final ValueChanged<SignalementStatut?> onSignalementFilter;
  final ValueChanged<ElementStatut?> onElementFilter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              avatar: const Icon(Icons.report_outlined, size: 18),
              label: const Text('Signalements'),
              selected: showSignalements,
              onSelected: onShowSignalements,
            ),
            if (showSignalements) ...[
              ChoiceChip(
                label: const Text('Tous'),
                selected: signalementFilter == null,
                onSelected: (_) => onSignalementFilter(null),
              ),
              for (final s in SignalementStatut.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: signalementFilter == s,
                  onSelected: (_) => onSignalementFilter(s),
                ),
            ],
            const VerticalDivider(width: 16),
            FilterChip(
              avatar: const Icon(Icons.star_outline, size: 18),
              label: const Text('Éléments remarquables'),
              selected: showElements,
              onSelected: onShowElements,
            ),
            if (showElements) ...[
              ChoiceChip(
                label: const Text('Tous'),
                selected: elementFilter == null,
                onSelected: (_) => onElementFilter(null),
              ),
              for (final e in ElementStatut.values)
                ChoiceChip(
                  label: Text(e.label),
                  selected: elementFilter == e,
                  onSelected: (_) => onElementFilter(e),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detail card shown at the bottom of the map when a report marker is
/// tapped, with the same moderation actions as the Signalements screen.
class MapSignalementCard extends StatelessWidget {
  const MapSignalementCard(
      {super.key, required this.signalement, required this.repo, required this.onClose});

  final Signalement signalement;
  final RandoRepository repo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = signalement;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.categorie.icon, color: s.statut.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.categorie.label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                StatusChip(label: s.statut.label, color: s.statut.color, dense: true),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            Text('${s.itineraireNom} · ${formatDateTime(s.createdAt)} · +${s.votes}',
                style: const TextStyle(color: RandoColors.inkMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(s.description),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => changeSignalementStatut(context, repo, s),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Changer le statut'),
                ),
                OutlinedButton.icon(
                  onPressed: () => deleteSignalementConfirm(context, repo, s),
                  icon: const Icon(Icons.delete_outline, color: RandoColors.danger),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail card shown at the bottom of the map when a point-of-interest
/// marker is tapped, with the same moderation actions as the Éléments
/// remarquables screen.
class MapElementCard extends StatelessWidget {
  const MapElementCard(
      {super.key, required this.element, required this.repo, required this.onClose});

  final ElementRemarquable element;
  final RandoRepository repo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final e = element;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(e.categorie.icon, color: e.statut.color),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text(e.titre, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                StatusChip(label: e.statut.label, color: e.statut.color, dense: true),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            Text(e.itineraireNom,
                style: const TextStyle(color: RandoColors.inkMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(e.description),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (e.statut != ElementStatut.valide)
                  FilledButton.icon(
                    onPressed: () => validateElement(context, repo, e),
                    icon: const Icon(Icons.check),
                    label: const Text('Valider'),
                  ),
                if (e.statut != ElementStatut.refuse)
                  OutlinedButton.icon(
                    onPressed: () => refuseElement(context, repo, e),
                    icon: const Icon(Icons.close),
                    label: const Text('Refuser'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => deleteElementConfirm(context, repo, e),
                  icon: const Icon(Icons.delete_outline, color: RandoColors.danger),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
