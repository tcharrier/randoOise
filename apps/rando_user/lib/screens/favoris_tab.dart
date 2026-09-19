import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/itineraire_card.dart';
import 'itineraire_detail_screen.dart';

class FavorisTab extends StatelessWidget {
  const FavorisTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.favoriteItineraires;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes favoris')),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('Aucun favori pour le moment', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Touchez le cœur d’un circuit pour le retrouver ici, même hors ligne.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => ItineraireCard(
                itineraire: list[i],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ItineraireDetailScreen(itineraireId: list[i].id),
                )),
              ),
            ),
    );
  }
}
