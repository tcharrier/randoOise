import 'package:flutter/material.dart';

/// Stable colour palette used to tell routes apart on the overview map.
/// The colour for a given id never changes across rebuilds.
class RoutePalette {
  RoutePalette._();

  static const List<Color> _colors = [
    Color(0xFF2F6B45),
    Color(0xFFD98E04),
    Color(0xFF2B6CB0),
    Color(0xFFC0392B),
    Color(0xFF6B46C1),
    Color(0xFF319795),
    Color(0xFFB83280),
    Color(0xFF718096),
    Color(0xFF975A16),
    Color(0xFF276749),
    Color(0xFF2C5282),
    Color(0xFF9B2C2C),
  ];

  static Color forId(String id) {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _colors[hash % _colors.length];
  }
}
