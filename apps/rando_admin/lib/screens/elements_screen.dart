import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../admin_data.dart';
import '../utils/date_format.dart';
import '../widgets/element_actions.dart';
import '../widgets/empty_state.dart';

/// Moderation queue for points of interest proposed by hikers.
class ElementsScreen extends StatefulWidget {
  const ElementsScreen({super.key, required this.onShowOnMap});

  final void Function(LatLng point, {String? title}) onShowOnMap;

  @override
  State<ElementsScreen> createState() => _ElementsScreenState();
}

class _ElementsScreenState extends State<ElementsScreen> {
  ElementStatut? _filter = ElementStatut.enAttente;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AdminData>();
    final repo = context.read<RandoRepository>();
    final all = data.elements;
    final filtered =
        _filter == null ? all : all.where((e) => e.statut == _filter).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Éléments remarquables',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ElementStatut?>(
              segments: [
                for (final e in ElementStatut.values)
                  ButtonSegment(
                    value: e,
                    label:
                        Text('${e.label} (${all.where((x) => x.statut == e).length})'),
                  ),
                ButtonSegment(value: null, label: Text('Tous (${all.length})')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    message: 'Aucun élément dans cette catégorie.',
                    icon: Icons.star_outline)
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ElementRow(
                      element: filtered[i],
                      repo: repo,
                      onShowOnMap: widget.onShowOnMap,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ElementRow extends StatelessWidget {
  const _ElementRow(
      {required this.element, required this.repo, required this.onShowOnMap});

  final ElementRemarquable element;
  final RandoRepository repo;
  final void Function(LatLng point, {String? title}) onShowOnMap;

  String _shortUid(String uid) => uid.length <= 8 ? uid : '${uid.substring(0, 8)}…';

  @override
  Widget build(BuildContext context) {
    final e = element;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(e.categorie.icon, color: e.statut.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.titre,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      StatusChip(label: e.statut.label, color: e.statut.color, dense: true),
                    ],
                  ),
                  Text('${e.categorie.label} · ${e.itineraireNom}',
                      style: const TextStyle(color: RandoColors.inkMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(e.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                      'Auteur ${_shortUid(e.auteurId)} · ${formatDateTime(e.createdAt)}',
                      style: const TextStyle(color: RandoColors.inkMuted, fontSize: 11)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (e.statut == ElementStatut.enAttente)
                        FilledButton.icon(
                          onPressed: () => validateElement(context, repo, e),
                          icon: const Icon(Icons.check),
                          label: const Text('Valider'),
                        )
                      else if (e.statut != ElementStatut.valide)
                        OutlinedButton.icon(
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
                        onPressed: () => onShowOnMap(e.position, title: e.titre),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Voir sur la carte'),
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
          ],
        ),
      ),
    );
  }
}
