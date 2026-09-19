import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../session.dart';
import 'confirm_dialog.dart';

Future<void> validateElement(
    BuildContext context, RandoRepository repo, ElementRemarquable element) async {
  final uid = context.read<AdminSession>().user?.uid ?? '';
  await repo.setElementStatut(element.id, ElementStatut.valide, adminUid: uid);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Élément validé.')));
  }
}

Future<void> refuseElement(
    BuildContext context, RandoRepository repo, ElementRemarquable element) async {
  final uid = context.read<AdminSession>().user?.uid ?? '';
  await repo.setElementStatut(element.id, ElementStatut.refuse, adminUid: uid);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Élément refusé.')));
  }
}

Future<void> deleteElementConfirm(
    BuildContext context, RandoRepository repo, ElementRemarquable element) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Supprimer cet élément ?',
    message: 'L\'élément « ${element.titre} » sera définitivement supprimé.',
    confirmLabel: 'Supprimer',
    danger: true,
  );
  if (ok) {
    await repo.deleteElement(element.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Élément supprimé.')));
    }
  }
}
