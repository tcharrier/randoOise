import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/itineraire_card.dart';
import '../widgets/ui.dart';
import 'itineraire_detail_screen.dart';

class FavorisScreen extends StatelessWidget {
  const FavorisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.favoriteItineraires;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Mes favoris',
              subtitle: list.isEmpty ? null : '${list.length} circuit${list.length > 1 ? 's' : ''} enregistré${list.length > 1 ? 's' : ''}',
              leading: RoundIconButton(icon: Icons.arrow_back_rounded, label: 'Retour', onPressed: () => Navigator.of(context).pop()),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Aucun favori',
                      subtitle: 'Touche le cœur d’un circuit pour le retrouver ici, même sans réseau.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => ItineraireCard(
                        itineraire: list[i],
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ItineraireDetailScreen(itineraireId: list[i].id),
                        )),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
