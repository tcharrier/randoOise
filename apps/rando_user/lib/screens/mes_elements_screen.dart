import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/element_tile.dart';
import '../widgets/ui.dart';
import 'sheets.dart';

/// Points of interest proposed from this device, with their moderation
/// statut (en attente / validé / refusé).
class MesElementsScreen extends StatelessWidget {
  const MesElementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.myElements;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Mes éléments remarquables',
              subtitle: 'Tes propositions et leur état de validation.',
              leading: RoundIconButton(
                  icon: Icons.arrow_back_rounded, label: 'Retour', onPressed: () => Navigator.of(context).pop()),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.place_outlined,
                      title: 'Aucune proposition',
                      subtitle: 'Depuis la fiche d’un circuit, propose un lavoir, un point de vue, un arbre remarquable…',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => ElementTile(
                        element: list[i],
                        showItineraire: true,
                        onTap: () => showElementSheet(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
