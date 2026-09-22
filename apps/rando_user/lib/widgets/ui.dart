import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rando_core/rando_core.dart';


/// Circular button on a soft surface (back, theme toggle, map controls).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.size = 52,
    this.filled = false,
    this.active = false,
    this.elevated = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final bool active;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = filled
        ? scheme.onSurface
        : (active ? scheme.primaryContainer : scheme.surface);
    final fg = filled
        ? scheme.surface
        : (active ? scheme.onPrimaryContainer : scheme.onSurface);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        elevation: elevated ? 3 : 0,
        shadowColor: Colors.black38,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Tooltip(
              message: label,
              child: Icon(icon, color: fg, size: size * 0.44),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded coloured square holding an icon (the "place" icon in the mockups).
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.radius = 14,
    this.solid = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: dark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: solid ? Colors.white : color, size: size * 0.52),
    );
  }
}

/// "Titre ......... Voir tout >"
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.padding});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(0, 28, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: theme.textTheme.headlineSmall)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Translucent stat pill used inside the hero card.
class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.icon, required this.label, required this.value, this.onDark = false});

  final IconData icon;
  final String label;
  final String value;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = onDark ? Colors.white : theme.colorScheme.onSurface;
    final soft = onDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (onDark ? Colors.white : Colors.white).withValues(alpha: onDark ? 0.14 : 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: soft)),
              Text(value, style: theme.textTheme.titleSmall?.copyWith(color: fg)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact inline stat "icon value" used on cards.
class InlineStat extends StatelessWidget {
  const InlineStat({super.key, required this.icon, required this.text, this.color, this.bold = false});

  final IconData icon;
  final String text;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(color: c, fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
        ),
      ],
    );
  }
}

/// Rounded card row: icon box, title, subtitle, trailing value.
class InfoRowCard extends StatelessWidget {
  const InfoRowCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              IconBox(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              if (chevron) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill label on top of a map (e.g. "6,2 km · 2h").
class MapLabel extends StatelessWidget {
  const MapLabel(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Text(text, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Decorative contour-line background for hero cards.
class TopoBackground extends StatelessWidget {
  const TopoBackground({super.key, required this.color, this.child});
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _TopoPainter(color),
        child: child,
      );
}

class _TopoPainter extends CustomPainter {
  _TopoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final cx = size.width * 0.78;
    final cy = size.height * 0.42;
    for (var i = 1; i <= 7; i++) {
      final r = i * 34.0;
      final path = Path();
      for (var a = 0; a <= 360; a += 6) {
        final rad = a * math.pi / 180;
        final wobble = 1 + 0.12 * math.sin(3 * rad + i) + 0.06 * math.cos(5 * rad - i);
        final x = cx + r * wobble * math.cos(rad);
        final y = cy + r * 0.72 * wobble * math.sin(rad);
        if (a == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TopoPainter old) => old.color != color;
}

/// Avatar circle with initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 52});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((e) => e[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: kRandoDisplayFont,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Simple empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBox(icon: icon, color: theme.colorScheme.primary, size: 72, radius: 24),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Page header used by tabs: big title, optional subtitle and trailing buttons.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing = const [], this.leading});
  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.displaySmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          for (final w in trailing) ...[const SizedBox(width: 8), w],
        ],
      ),
    );
  }
}
