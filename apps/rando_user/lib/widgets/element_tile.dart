import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';
import 'ui.dart';

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
    final color = e.isValide ? RandoColors.blue : e.statut.color;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBox(icon: e.categorie.icon, color: color, size: 46, radius: 15),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.titre, style: theme.textTheme.titleMedium),
                    if (showItineraire)
                      Text(e.itineraireNom,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: e.isValide
                              ? "Validé par l'ARC"
                              : (e.isAuthor(uid) ? 'Votre proposition · ${e.statut.label.toLowerCase()}' : e.statut.label),
                          color: color,
                          icon: e.isValide ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                          dense: true,
                        ),
                        Text(formatRelative(e.createdAt), style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
