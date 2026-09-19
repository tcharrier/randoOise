import 'package:flutter/material.dart';

/// A small circular pin used for markers on every map in the app.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pin = Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.56),
    );
    if (onTap == null) return pin;
    return GestureDetector(onTap: onTap, child: pin);
  }
}

/// Small map attribution text, positioned by the caller.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.white70,
      child: const Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 10, color: Colors.black87),
      ),
    );
  }
}
