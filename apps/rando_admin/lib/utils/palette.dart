import 'package:flutter/material.dart';
import 'package:rando_core/rando_core.dart';

/// Stable colour palette used to tell routes apart on the overview map.
/// The colour for a given id never changes across rebuilds. Hiking routes
/// pick from a warm family, cycling routes from a cool blue family, so the
/// two networks stay visually distinguishable while individual routes
/// within a network still get a distinct shade.
class RoutePalette {
  RoutePalette._();

  static const List<Color> _pied = [
    Color(0xFF2F6B45),
    Color(0xFFD98E04),
    Color(0xFFC0392B),
    Color(0xFF975A16),
    Color(0xFF276749),
    Color(0xFFB83280),
    Color(0xFF9B2C2C),
    Color(0xFFAA6C39),
  ];

  static const List<Color> _velo = [
    Color(0xFF1D7CF2),
    Color(0xFF2B6CB0),
    Color(0xFF319795),
    Color(0xFF2C5282),
    Color(0xFF0E7490),
    Color(0xFF3B6FD9),
    Color(0xFF1F7A8C),
    Color(0xFF145A68),
  ];

  static Color forRoute(String id, Activite activite) {
    final colors = activite == Activite.velo ? _velo : _pied;
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return colors[hash % colors.length];
  }
}
