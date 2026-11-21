import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../services/weather_service.dart';
import '../util/format.dart';
import 'ui.dart';

/// Sky colours for a condition.
class WeatherPalette {
  const WeatherPalette({required this.top, required this.bottom, required this.onDark});
  final Color top;
  final Color bottom;

  /// True when text should be white on this background.
  final bool onDark;

  static WeatherPalette of(WeatherKind kind, bool isDay) {
    if (!isDay) {
      switch (kind) {
        case WeatherKind.clear:
        case WeatherKind.mainlyClear:
          return const WeatherPalette(top: Color(0xFF0F1B3D), bottom: Color(0xFF2A3C7A), onDark: true);
        default:
          return const WeatherPalette(top: Color(0xFF1C2333), bottom: Color(0xFF3A4660), onDark: true);
      }
    }
    switch (kind) {
      case WeatherKind.clear:
        return const WeatherPalette(top: Color(0xFF4FA3F0), bottom: Color(0xFFBFE3FF), onDark: false);
      case WeatherKind.mainlyClear:
      case WeatherKind.partlyCloudy:
        return const WeatherPalette(top: Color(0xFF6DB0EE), bottom: Color(0xFFD3E8F8), onDark: false);
      case WeatherKind.overcast:
        return const WeatherPalette(top: Color(0xFF8EA6C2), bottom: Color(0xFFD5DEE8), onDark: false);
      case WeatherKind.fog:
        return const WeatherPalette(top: Color(0xFF9AA6B2), bottom: Color(0xFFD8DEE4), onDark: false);
      case WeatherKind.drizzle:
      case WeatherKind.rain:
        return const WeatherPalette(top: Color(0xFF5B7089), bottom: Color(0xFFA7B8CA), onDark: true);
      case WeatherKind.heavyRain:
        return const WeatherPalette(top: Color(0xFF41546B), bottom: Color(0xFF8396AC), onDark: true);
      case WeatherKind.snow:
        return const WeatherPalette(top: Color(0xFFA9BBCF), bottom: Color(0xFFEAF0F6), onDark: false);
      case WeatherKind.thunder:
        return const WeatherPalette(top: Color(0xFF2E3A55), bottom: Color(0xFF66779A), onDark: true);
    }
  }
}

/// Animated weather icon: sun with turning rays, drifting clouds, falling
/// rain or snow, lightning flashes… Pure Flutter, no assets.
class WeatherScene extends StatefulWidget {
  const WeatherScene({super.key, required this.kind, required this.isDay, this.size = 64});
  final WeatherKind kind;
  final bool isDay;
  final double size;

  @override
  State<WeatherScene> createState() => _WeatherSceneState();
}

class _WeatherSceneState extends State<WeatherScene> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.kind.label,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => CustomPaint(painter: _WeatherPainter(widget.kind, widget.isDay, _ctrl.value)),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.kind, this.isDay, this.t);
  final WeatherKind kind;
  final bool isDay;
  final double t; // 0..1 looping

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    switch (kind) {
      case WeatherKind.clear:
        isDay ? _sun(canvas, s, Offset(s / 2, s / 2), s * 0.24) : _moon(canvas, s, Offset(s / 2, s / 2), s * 0.24);
      case WeatherKind.mainlyClear:
        if (isDay) {
          _sun(canvas, s, Offset(s * 0.42, s * 0.42), s * 0.22);
        } else {
          _moon(canvas, s, Offset(s * 0.42, s * 0.42), s * 0.22);
        }
        _cloud(canvas, s, Offset(s * 0.62, s * 0.66), s * 0.15, Colors.white.withValues(alpha: 0.95), drift: 0.6);
      case WeatherKind.partlyCloudy:
        if (isDay) {
          _sun(canvas, s, Offset(s * 0.36, s * 0.36), s * 0.2);
        } else {
          _moon(canvas, s, Offset(s * 0.36, s * 0.36), s * 0.2);
        }
        _cloud(canvas, s, Offset(s * 0.58, s * 0.6), s * 0.2, Colors.white, drift: 1);
      case WeatherKind.overcast:
        _cloud(canvas, s, Offset(s * 0.36, s * 0.42), s * 0.17, const Color(0xFFDDE4EC), drift: 0.8);
        _cloud(canvas, s, Offset(s * 0.58, s * 0.6), s * 0.21, Colors.white, drift: 1.2);
      case WeatherKind.fog:
        _fog(canvas, s);
      case WeatherKind.drizzle:
        _cloud(canvas, s, Offset(s * 0.5, s * 0.42), s * 0.2, const Color(0xFFE3E9F0), drift: 0.5);
        _rain(canvas, s, count: 5, speed: 0.8, length: 0.08);
      case WeatherKind.rain:
        _cloud(canvas, s, Offset(s * 0.5, s * 0.4), s * 0.2, const Color(0xFFD9E0E8), drift: 0.5);
        _rain(canvas, s, count: 9, speed: 1.2, length: 0.12);
      case WeatherKind.heavyRain:
        _cloud(canvas, s, Offset(s * 0.5, s * 0.38), s * 0.21, const Color(0xFFB9C4D0), drift: 0.4);
        _rain(canvas, s, count: 14, speed: 1.6, length: 0.16);
      case WeatherKind.snow:
        _cloud(canvas, s, Offset(s * 0.5, s * 0.4), s * 0.2, Colors.white, drift: 0.5);
        _snow(canvas, s, count: 9);
      case WeatherKind.thunder:
        _cloud(canvas, s, Offset(s * 0.5, s * 0.38), s * 0.21, const Color(0xFF8A96A8), drift: 0.4);
        _rain(canvas, s, count: 7, speed: 1.4, length: 0.12);
        _lightning(canvas, s);
    }
  }

  void _sun(Canvas canvas, double s, Offset c, double r) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFE08A).withValues(alpha: 0.55), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c, radius: r * 2.1));
    canvas.drawCircle(c, r * 2.1, glow);
    final rayPaint = Paint()
      ..color = const Color(0xFFFFC53D)
      ..strokeWidth = math.max(1.5, s * 0.04)
      ..strokeCap = StrokeCap.round;
    final angle = t * 2 * math.pi;
    for (var i = 0; i < 8; i++) {
      final a = angle + i * math.pi / 4;
      final pulse = 1 + 0.08 * math.sin(t * 2 * math.pi * 2 + i);
      final from = c + Offset(math.cos(a), math.sin(a)) * r * 1.35;
      final to = c + Offset(math.cos(a), math.sin(a)) * r * 1.75 * pulse;
      canvas.drawLine(from, to, rayPaint);
    }
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFB800));
    canvas.drawCircle(c, r * 0.8, Paint()..color = const Color(0xFFFFD25C));
  }

  void _moon(Canvas canvas, double s, Offset c, double r) {
    final rnd = math.Random(7);
    for (var i = 0; i < 6; i++) {
      final p = Offset(rnd.nextDouble() * s, rnd.nextDouble() * s * 0.7);
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 1.5 + i * 1.3));
      canvas.drawCircle(p, s * 0.02, Paint()..color = Colors.white.withValues(alpha: tw));
    }
    final path = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c + Offset(r * 0.55, -r * 0.35), radius: r * 0.85)),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFF5F0C8));
  }

  void _cloud(Canvas canvas, double s, Offset c, double r, Color color, {double drift = 1}) {
    final dx = math.sin(t * 2 * math.pi) * s * 0.035 * drift;
    final cc = c + Offset(dx, 0);
    final paint = Paint()..color = color;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.08);
    final path = Path()
      ..addOval(Rect.fromCircle(center: cc + Offset(-r * 0.9, r * 0.2), radius: r * 0.75))
      ..addOval(Rect.fromCircle(center: cc + Offset(-r * 0.15, -r * 0.35), radius: r))
      ..addOval(Rect.fromCircle(center: cc + Offset(r * 0.8, r * 0.1), radius: r * 0.8))
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cc.dx - r * 1.55, cc.dy + r * 0.1, r * 3.1, r * 0.85), Radius.circular(r * 0.4)));
    canvas.drawPath(path.shift(const Offset(0, 2)), shadow);
    canvas.drawPath(path, paint);
  }

  void _rain(Canvas canvas, double s, {required int count, required double speed, required double length}) {
    final paint = Paint()
      ..color = const Color(0xFF7FB3F5)
      ..strokeWidth = math.max(1.2, s * 0.035)
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(3);
    for (var i = 0; i < count; i++) {
      final x0 = s * (0.2 + rnd.nextDouble() * 0.6);
      final phase = rnd.nextDouble();
      final y = ((t * speed + phase) % 1.0);
      final yPx = s * (0.55 + y * 0.45);
      if (yPx > s) continue;
      final from = Offset(x0 + s * 0.03, yPx);
      final to = Offset(x0, yPx + s * length);
      canvas.drawLine(from, to, paint..color = const Color(0xFF7FB3F5).withValues(alpha: 1 - y * 0.6));
    }
  }

  void _snow(Canvas canvas, double s, {required int count}) {
    final rnd = math.Random(5);
    for (var i = 0; i < count; i++) {
      final x0 = s * (0.2 + rnd.nextDouble() * 0.6);
      final phase = rnd.nextDouble();
      final y = ((t * 0.6 + phase) % 1.0);
      final sway = math.sin((t + phase) * 2 * math.pi * 2) * s * 0.03;
      final p = Offset(x0 + sway, s * (0.55 + y * 0.45));
      if (p.dy > s) continue;
      canvas.drawCircle(p, s * 0.028, Paint()..color = Colors.white.withValues(alpha: 1 - y * 0.5));
    }
  }

  void _fog(Canvas canvas, double s) {
    for (var i = 0; i < 4; i++) {
      final dx = math.sin(t * 2 * math.pi + i) * s * 0.06;
      final y = s * (0.3 + i * 0.15);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75 - i * 0.12)
        ..strokeWidth = s * 0.07
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(s * 0.18 + dx, y), Offset(s * 0.82 + dx, y), paint);
    }
  }

  void _lightning(Canvas canvas, double s) {
    final phase = (t * 2) % 1.0;
    if (phase > 0.16) return;
    final alpha = phase < 0.08 ? 1.0 : 1 - (phase - 0.08) / 0.08;
    final c = Offset(s * 0.5, s * 0.55);
    final path = Path()
      ..moveTo(c.dx + s * 0.04, c.dy)
      ..lineTo(c.dx - s * 0.06, c.dy + s * 0.2)
      ..lineTo(c.dx + s * 0.01, c.dy + s * 0.2)
      ..lineTo(c.dx - s * 0.05, c.dy + s * 0.42)
      ..lineTo(c.dx + s * 0.1, c.dy + s * 0.16)
      ..lineTo(c.dx + s * 0.02, c.dy + s * 0.16)
      ..lineTo(c.dx + s * 0.1, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFE066).withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.t != t || old.kind != kind || old.isDay != isDay;
}

/// Home tile: animated sky, current temperature and condition. With
/// [compact] it fits in a half-width, half-height slot (about 52 px high).
class WeatherTile extends StatelessWidget {
  const WeatherTile({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<AppState>().weather;
    return AnimatedBuilder(
      animation: weather,
      builder: (context, _) {
        final snap = weather.snapshot;
        final theme = Theme.of(context);
        if (snap == null) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => weather.refresh(force: true),
              child: Padding(
                padding: compact ? const EdgeInsets.fromLTRB(10, 6, 8, 6) : const EdgeInsets.all(14),
                child: compact
                    ? Row(
                        children: [
                          const IconBox(icon: Icons.cloud_outlined, color: RandoColors.blue, size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              weather.loading ? 'Météo…' : 'Météo indisponible',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const IconBox(icon: Icons.cloud_outlined, color: RandoColors.blue, size: 46),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              weather.loading ? 'Chargement de la météo…' : 'Météo indisponible. Touche pour réessayer.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        }
        final pal = WeatherPalette.of(snap.now.kind, snap.now.isDay);
        final fg = pal.onDark ? Colors.white : RandoColors.ink;
        final soft = pal.onDark ? Colors.white70 : RandoColors.inkSoft;
        return RepaintBoundary(
          child: Semantics(
            button: true,
            label: 'Météo ${snap.place} : ${snap.now.tempC.round()} degrés, ${snap.now.kind.label}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(RandoRadius.card),
                onTap: () => showWeatherSheet(context),
                child: Ink(
                  height: compact ? double.infinity : null,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RandoRadius.card),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pal.top, pal.bottom]),
                  ),
                  child: Padding(
                    padding: compact ? const EdgeInsets.fromLTRB(8, 4, 4, 4) : const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: compact
                        ? Row(
                            children: [
                              WeatherScene(kind: snap.now.kind, isDay: snap.now.isDay, size: 34),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text('${snap.now.tempC.round()}°', style: theme.textTheme.headlineSmall?.copyWith(color: fg)),
                                    ),
                                    Text(
                                      snap.now.kind.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(color: soft),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: fg, size: 18),
                            ],
                          )
                        : Row(
                            children: [
                              WeatherScene(kind: snap.now.kind, isDay: snap.now.isDay, size: 64),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${snap.now.tempC.round()}°', style: theme.textTheme.displaySmall?.copyWith(color: fg)),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 5),
                                            child: Text(
                                              snap.now.kind.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleSmall?.copyWith(color: fg),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${snap.place} · ${_nextHoursLine(snap)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(color: soft),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: fg),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _nextHoursLine(WeatherSnapshot snap) {
    if (snap.hours.isEmpty) return 'prochaines heures indisponibles';
    final wet = snap.hours.where((h) => h.kind.isWet).length;
    if (wet == 0) return 'pas de pluie dans les ${snap.hours.length} prochaines heures';
    final first = snap.hours.firstWhere((h) => h.kind.isWet);
    return 'pluie possible vers ${formatHour(first.time)}';
  }
}

/// Bottom sheet: big animated sky, current details and the next 5 hours.
Future<void> showWeatherSheet(BuildContext context) {
  final weather = context.read<AppState>().weather;
  weather.refresh();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: weather,
      builder: (ctx, _) {
        final snap = weather.snapshot;
        final theme = Theme.of(ctx);
        final maxH = MediaQuery.of(ctx).size.height * 0.88;
        if (snap == null) {
          return SizedBox(
            height: 220,
            child: Center(
              child: weather.loading
                  ? const CircularProgressIndicator()
                  : Text('Météo indisponible pour le moment.', style: theme.textTheme.bodyLarge),
            ),
          );
        }
        final pal = WeatherPalette.of(snap.now.kind, snap.now.isDay);
        final fg = pal.onDark ? Colors.white : RandoColors.ink;
        final soft = pal.onDark ? Colors.white70 : RandoColors.inkSoft;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(ctx).viewPadding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(RandoRadius.card + 4),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pal.top, pal.bottom]),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: 16,
                          top: 16,
                          child: WeatherScene(kind: snap.now.kind, isDay: snap.now.isDay, size: 120),
                        ),
                        Positioned(
                          left: 20,
                          bottom: 18,
                          right: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(snap.place, style: theme.textTheme.titleMedium?.copyWith(color: soft)),
                              Text('${snap.now.tempC.round()}°', style: theme.textTheme.displayLarge?.copyWith(color: fg, fontSize: 56)),
                              Text(snap.now.kind.label, style: theme.textTheme.titleMedium?.copyWith(color: fg)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Detail(icon: Icons.air_rounded, label: 'Vent', value: '${snap.now.windKmh.round()} km/h'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Detail(
                        icon: Icons.umbrella_rounded,
                        label: 'Pluie (5 h)',
                        value: snap.hours.isEmpty ? '–' : '${snap.hours.map((h) => h.precipProbability).reduce(math.max)} %',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Detail(
                        icon: Icons.thermostat_rounded,
                        label: 'Dans 5 h',
                        value: snap.hours.isEmpty ? '–' : '${snap.hours.last.tempC.round()}°',
                      ),
                    ),
                  ],
                ),
                const SectionHeader('Les 5 prochaines heures', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
                if (snap.hours.isEmpty)
                  Text('Prévisions horaires indisponibles.', style: theme.textTheme.bodyMedium)
                else
                  Row(
                    children: [
                      for (final h in snap.hours) ...[Expanded(child: _HourCard(h)), if (h != snap.hours.last) const SizedBox(width: 8)],
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('Source Open-Meteo · mis à jour ${formatRelative(snap.fetchedAt)}', style: theme.textTheme.bodySmall),
                    ),
                    TextButton.icon(
                      onPressed: weather.loading ? null : () => weather.refresh(force: true),
                      icon: weather.loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
                if (weather.error != null)
                  Text(
                    'Dernière tentative en échec : hors ligne ?',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleMedium),
            Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _HourCard extends StatelessWidget {
  const _HourCard(this.h);
  final WeatherHour h;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = WeatherPalette.of(h.kind, h.isDay);
    final fg = pal.onDark ? Colors.white : RandoColors.ink;
    final soft = pal.onDark ? Colors.white70 : RandoColors.inkSoft;
    return Semantics(
      label: '${formatHour(h.time)} : ${h.tempC.round()} degrés, ${h.kind.label}, ${h.precipProbability} % de pluie',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pal.top, pal.bottom]),
        ),
        child: Column(
          children: [
            Text(formatHour(h.time), style: theme.textTheme.labelMedium?.copyWith(color: soft)),
            const SizedBox(height: 4),
            WeatherScene(kind: h.kind, isDay: h.isDay, size: 40),
            const SizedBox(height: 4),
            Text('${h.tempC.round()}°', style: theme.textTheme.titleMedium?.copyWith(color: fg)),
            Text('${h.precipProbability} %', style: theme.textTheme.labelSmall?.copyWith(color: soft)),
          ],
        ),
      ),
    );
  }
}
