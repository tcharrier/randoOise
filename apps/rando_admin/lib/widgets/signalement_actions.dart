import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../session.dart';
import 'confirm_dialog.dart';

/// Opens a small picker to change the status of [signalement], then an
/// optional comment dialog, and persists both through [repo].
Future<void> changeSignalementStatut(
    BuildContext context, RandoRepository repo, Signalement signalement) async {
  final statut = await showDialog<SignalementStatut>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Changer le statut'),
      children: [
        for (final s in SignalementStatut.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(s),
            child: Row(
              children: [
                StatusChip(label: s.label, color: s.color),
                if (s == signalement.statut) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
      ],
    ),
  );
  if (statut == null || !context.mounted) return;
  final comment = await showCommentDialog(
    context,
    title: 'Commentaire administrateur',
    initialValue: signalement.commentaireAdmin,
  );
  if (!context.mounted) return;
  final uid = context.read<AdminSession>().user?.uid ?? '';
  await repo.setSignalementStatut(
    signalement.id,
    statut,
    adminUid: uid,
    commentaire: (comment == null || comment.isEmpty) ? null : comment,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Statut mis à jour : ${statut.label}')),
    );
  }
}

Future<void> deleteSignalementConfirm(
    BuildContext context, RandoRepository repo, Signalement signalement) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Supprimer ce signalement ?',
    message:
        'Le signalement « ${signalement.categorie.label} » sera définitivement supprimé.',
    confirmLabel: 'Supprimer',
    danger: true,
  );
  if (ok) {
    await repo.deleteSignalement(signalement.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Signalement supprimé.')));
    }
  }
}
