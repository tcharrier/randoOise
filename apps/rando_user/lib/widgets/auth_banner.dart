import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

/// Shown on the forms while the device is not signed in, with the reason
/// (service not enabled vs. no network) and a retry button.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.uid != null || state.authError == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(child: Text(state.authError!, style: TextStyle(color: scheme.onErrorContainer))),
          TextButton(onPressed: state.requireUid, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
