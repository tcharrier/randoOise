import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';

class ElementTile extends StatelessWidget {
  const ElementTile({super.key, required this.element, this.onTap, this.showItineraire = false});

  final ElementRemarquable element;
  final VoidCallback? onTap;
  final bool showItineraire;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final uid = context.watch<AppState>().uid;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = e.isValide ? RandoColors.water : e.statut.color;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(e.categorie.icon, color: color),
        ),
        title: Text(e.titre, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showItineraire)
              Text(e.itineraireNom, style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
            if (e.description.isNotEmpty)
              Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  label: e.isValide
                      ? "Validé par l'ARC"
                      : (e.isAuthor(uid) ? 'Votre proposition · ${e.statut.label.toLowerCase()}' : e.statut.label),
                  color: color,
                  icon: e.isValide ? Icons.verified : Icons.hourglass_top,
                  dense: true,
                ),
                Text(formatDate(e.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
