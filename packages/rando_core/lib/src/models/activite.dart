import 'package:flutter/material.dart';

/// Kind of outing a route is meant for. Hiking routes come from the
/// Firestore sources, cycling routes from the dataset embedded in the app
/// (and optionally mirrored in Firestore for the admin).
enum Activite {
  pied('pied', 'À pied', 'Randonnée', Icons.hiking_rounded, Color(0xFF1F6B4A)),
  velo('velo', 'À vélo', 'Vélo', Icons.directions_bike_rounded, Color(0xFF1F7A8C));

  const Activite(this.code, this.label, this.shortLabel, this.icon, this.color);

  /// Value stored in Firestore.
  final String code;

  /// "À pied" / "À vélo".
  final String label;

  /// "Randonnée" / "Vélo".
  final String shortLabel;
  final IconData icon;
  final Color color;

  static Activite fromCode(String? code) =>
      Activite.values.firstWhere((a) => a.code == code, orElse: () => Activite.pied);
}

/// Operational status of a cycling route (from the ARC dataset).
enum StatutReseau {
  enService('en_service', 'En service', Color(0xFF2D6A4F)),
  enTravaux('en_travaux', 'En travaux', Color(0xFFB8781F)),
  provisoire('provisoire', 'Provisoire', Color(0xFF7B68EE));

  const StatutReseau(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;

  static StatutReseau? fromCode(String? code) {
    if (code == null) return null;
    for (final s in StatutReseau.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}
