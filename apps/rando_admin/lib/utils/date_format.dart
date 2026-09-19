/// Small manual date formatters (no intl dependency needed).
String formatDateTime(DateTime? dt) {
  if (dt == null) return '–';
  final local = dt.toLocal();
  final d = _two(local.day);
  final m = _two(local.month);
  final y = local.year.toString();
  final h = _two(local.hour);
  final min = _two(local.minute);
  return '$d/$m/$y $h:$min';
}

String formatDate(DateTime? dt) {
  if (dt == null) return '–';
  final local = dt.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

String _two(int v) => v.toString().padLeft(2, '0');
