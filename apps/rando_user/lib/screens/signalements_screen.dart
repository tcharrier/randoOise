import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../widgets/signalement_tile.dart';
import '../widgets/ui.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';

class SignalementsScreen extends StatefulWidget {
  const SignalementsScreen({super.key});

  @override
  State<SignalementsScreen> createState() => _SignalementsScreenState();
}

class _SignalementsScreenState extends State<SignalementsScreen> {
  SignalementStatut? _statut;
  String? _itineraireId;
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final list = state.signalements.where((s) {
      if (_statut != null && s.statut != _statut) return false;
      if (_itineraireId != null && s.itineraireId != _itineraireId) return false;
      if (_onlyMine && !s.isAuthor(state.uid)) return false;
      return true;
    }).toList();

    int count(SignalementStatut? st) => state.signalements.where((s) => st == null || s.statut == st).length;
    final selectedIt = _itineraireId == null ? null : state.itineraireById(_itineraireId!);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Signalements',
              subtitle: 'Problèmes remontés par les randonneurs, traités par l’ARC.',
              leading: RoundIconButton(icon: Icons.arrow_back_rounded, label: 'Retour', onPressed: () => Navigator.of(context).pop()),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final st in [null, ...SignalementStatut.values]) ...[
                    FilterChip(
                      label: Text('${st?.label ?? 'Tous'} · ${count(st)}'),
                      selected: _statut == st,
                      onSelected: (_) => setState(() => _statut = st),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilterChip(
                    avatar: Icon(Icons.person_outline_rounded, size: 16,
                        color: _onlyMine ? theme.colorScheme.surface : theme.colorScheme.onSurface),
                    label: const Text('Les miens'),
                    selected: _onlyMine,
                    onSelected: (v) => setState(() => _onlyMine = v),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String?>(
                    tooltip: 'Filtrer par circuit',
                    onSelected: (v) => setState(() => _itineraireId = v == '' ? null : v),
                    itemBuilder: (_) => [
                      const PopupMenuItem<String?>(value: '', child: Text('Tous les circuits')),
                      for (final it in state.itineraires) PopupMenuItem<String?>(value: it.id, child: Text(it.nom)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.route_rounded, size: 18),
                      label: Text(selectedIt?.nom ?? 'Tous les circuits', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Aucun signalement',
                      subtitle: 'Un problème sur un sentier ? Signale-le pour prévenir les autres randonneurs et l’ARC.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => SignalementTile(
                        signalement: list[i],
                        onTap: () => showSignalementSheet(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ElevatedButton.icon(
          onPressed: state.itineraires.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SignalementFormScreen(itineraire: selectedIt),
                  )),
          icon: const Icon(Icons.add_alert_rounded),
          label: const Text('Signaler un problème'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
