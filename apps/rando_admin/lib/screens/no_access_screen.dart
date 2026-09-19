import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../session.dart';

/// Shown when a Firebase user is authenticated but has no `admins/{uid}`
/// document.
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<AdminSession>();
    return Scaffold(
      backgroundColor: RandoColors.paper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, color: RandoColors.danger, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Accès refusé',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ce compte (${session.user?.email ?? ''}) n\'a pas les '
                    'droits administrateur sur Rando Oise.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: session.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
