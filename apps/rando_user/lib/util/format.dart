String two(int n) => n.toString().padLeft(2, '0');

/// "19/09/2026 14:05" without depending on intl.
String formatDate(DateTime? d, {bool time = true}) {
  if (d == null) return 'En attente d’envoi';
  final l = d.toLocal();
  final date = '${two(l.day)}/${two(l.month)}/${l.year}';
  return time ? '$date ${two(l.hour)}:${two(l.minute)}' : date;
}

String formatElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '${h}h${two(m)}' : '${two(m)}:${two(s)}';
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
