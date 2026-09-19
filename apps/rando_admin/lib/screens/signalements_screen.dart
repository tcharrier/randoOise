import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../admin_data.dart';
import '../utils/date_format.dart';
import '../widgets/empty_state.dart';
import '../widgets/signalement_actions.dart';

/// Moderation queue for hiker reports, grouped by status.
class SignalementsScreen extends StatefulWidget {
  const SignalementsScreen({super.key, required this.onShowOnMap});

  final void Function(LatLng point, {String? title}) onShowOnMap;

  @override
  State<SignalementsScreen> createState() => _SignalementsScreenState();
}

class _SignalementsScreenState extends State<SignalementsScreen> {
  SignalementStatut? _filter;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AdminData>();
    final repo = context.read<RandoRepository>();
    final all = data.signalements;
    final filtered =
        _filter == null ? all : all.where((s) => s.statut == _filter).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signalements',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<SignalementStatut?>(
              segments: [
                ButtonSegment(value: null, label: Text('Tous (${all.length})')),
                for (final s in SignalementStatut.values)
                  ButtonSegment(
                    value: s,
                    label: Text(
                        '${s.label} (${all.where((e) => e.statut == s).length})'),
                  ),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    message: 'Aucun signalement dans cette catégorie.',
                    icon: Icons.report_outlined)
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _SignalementRow(
                      signalement: filtered[i],
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

class _SignalementRow extends StatelessWidget {
  const _SignalementRow(
      {required this.signalement, required this.repo, required this.onShowOnMap});

  final Signalement signalement;
  final RandoRepository repo;
  final void Function(LatLng point, {String? title}) onShowOnMap;

  void _showFullDescription(BuildContext context) {
    final s = signalement;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.categorie.label),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.description),
              if (s.commentaireAdmin != null && s.commentaireAdmin!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Commentaire administrateur :',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(s.commentaireAdmin!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = signalement;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showFullDescription(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(s.categorie.icon, color: s.statut.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.categorie.label,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text(formatDateTime(s.createdAt),
                            style: const TextStyle(
                                color: RandoColors.inkMuted, fontSize: 12)),
                      ],
                    ),
                    Text(s.itineraireNom,
                        style:
                            const TextStyle(color: RandoColors.inkMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(s.description,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(label: s.statut.label, color: s.statut.color, dense: true),
                  const SizedBox(height: 6),
                  StatusChip(
                      label: '+${s.votes}',
                      color: RandoColors.water,
                      icon: Icons.how_to_vote_outlined,
                      dense: true),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'statut':
                      changeSignalementStatut(context, repo, s);
                      break;
                    case 'carte':
                      onShowOnMap(s.position, title: s.itineraireNom);
                      break;
                    case 'supprimer':
                      deleteSignalementConfirm(context, repo, s);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'statut', child: Text('Changer le statut')),
                  PopupMenuItem(value: 'carte', child: Text('Voir sur la carte')),
                  PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
