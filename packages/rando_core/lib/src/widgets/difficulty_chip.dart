import 'package:flutter/material.dart';

import '../theme/rando_theme.dart';
import 'status_chip.dart';

class DifficultyChip extends StatelessWidget {
  const DifficultyChip(this.difficulte, {super.key, this.dense = false});

  final String? difficulte;
  final bool dense;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: DifficultyStyle.label(difficulte),
        color: DifficultyStyle.color(difficulte),
        icon: Icons.terrain,
        dense: dense,
      );
}
