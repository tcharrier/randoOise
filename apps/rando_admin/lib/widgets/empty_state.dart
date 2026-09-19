import 'package:flutter/material.dart';
import 'package:rando_core/rando_core.dart';

/// Simple centered placeholder used by empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined,
                size: 40, color: RandoColors.inkMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: RandoColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
