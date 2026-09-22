String two(int n) => n.toString().padLeft(2, '0');

const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// "19/09/2026 14:05" without depending on intl.
String formatDate(DateTime? d, {bool time = true}) {
  if (d == null) return 'En attente d’envoi';
  final l = d.toLocal();
  final date = '${two(l.day)}/${two(l.month)}/${l.year}';
  return time ? '$date ${two(l.hour)}:${two(l.minute)}' : date;
}

/// "lundi 22 septembre"
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day == 1 ? '1er' : d.day} ${_months[d.month - 1]}';

/// "il y a 3 h", "hier", "12/09"
String formatRelative(DateTime? d) {
  if (d == null) return 'à l’instant';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
  return '${two(d.day)}/${two(d.month)}';
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

String plural(int n, String singular, [String? pluralForm]) =>
    '$n ${n > 1 ? (pluralForm ?? '${singular}s') : singular}';
