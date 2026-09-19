import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../widgets/signalement_tile.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';

class SignalementsTab extends StatefulWidget {
  const SignalementsTab({super.key});

  @override
  State<SignalementsTab> createState() => _SignalementsTabState();
}

class _SignalementsTabState extends State<SignalementsTab> {
  SignalementStatut? _statut;
  String? _itineraireId;
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    var list = state.signalements.where((s) {
      if (_statut != null && s.statut != _statut) return false;
      if (_itineraireId != null && s.itineraireId != _itineraireId) return false;
      if (_onlyMine && !s.isAuthor(state.uid)) return false;
      return true;
    }).toList();

    int count(SignalementStatut? st) =>
        state.signalements.where((s) => st == null || s.statut == st).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signalements'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final st in [null, ...SignalementStatut.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${st?.label ?? 'Tous'} (${count(st)})'),
                      selected: _statut == st,
                      onSelected: (_) => setState(() => _statut = st),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Les miens'),
                    selected: _onlyMine,
                    onSelected: (v) => setState(() => _onlyMine = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: DropdownButtonFormField<String?>(
              initialValue: _itineraireId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.route_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tous les itinéraires')),
                for (final it in state.itineraires)
                  DropdownMenuItem<String?>(
                    value: it.id,
                    child: Text(it.nom, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _itineraireId = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('Aucun signalement', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            'Un problème sur un sentier ? Signalez-le pour prévenir les autres randonneurs et l’ARC.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.itineraires.isEmpty
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SignalementFormScreen(
                    itineraire: _itineraireId == null ? null : state.itineraireById(_itineraireId!),
                  ),
                )),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Signaler'),
      ),
    );
  }
}
