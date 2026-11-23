/// "GOLDEN_RETRIEVER" -> "Golden Retriever"
String humanizeEnum(String value) => value
    .toLowerCase()
    .split('_')
    .where((p) => p.isNotEmpty)
    .map((p) => p[0].toUpperCase() + p.substring(1))
    .join(' ');

/// Lit une chaîne dans le JSON sans jamais planter :
/// si la clé manque ou n'est pas une String, renvoie null.
String? readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

/// "3 Years", "1 Year", "5 Months" à partir d'une date de naissance.
String ageLabelFor(DateTime birthDate, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var months =
      (today.year - birthDate.year) * 12 + today.month - birthDate.month;
  if (today.day < birthDate.day) months--;
  if (months < 0) months = 0;

  if (months < 12) return '$months ${months == 1 ? 'Month' : 'Months'}';
  final years = months ~/ 12;
  return '$years ${years == 1 ? 'Year' : 'Years'}';
}

/// Nombre de jours avant le prochain anniversaire (0 = aujourd'hui).
/// Un 29 février est fêté le 1er mars les années non bissextiles.
/// Renvoie null si la naissance est aujourd'hui ou dans le futur.
int? daysUntilBirthday(DateTime birthDate, {DateTime? now}) {
  final n = now ?? DateTime.now();
  // En UTC : un jour fait toujours 24 h (pas de changement d'heure).
  final today = DateTime.utc(n.year, n.month, n.day);
  final birth = DateTime.utc(birthDate.year, birthDate.month, birthDate.day);
  if (!birth.isBefore(today)) return null;

  var next = DateTime.utc(today.year, birth.month, birth.day);
  if (next.isBefore(today)) {
    next = DateTime.utc(today.year + 1, birth.month, birth.day);
  }
  return next.difference(today).inDays;
}

/// "Birthday today!", "Birthday tomorrow", "Birthday in 12 days",
/// ou null si l'anniversaire est dans plus de 30 jours.
String? birthdayLabelFor(DateTime birthDate, {DateTime? now}) {
  final days = daysUntilBirthday(birthDate, now: now);
  if (days == null || days > 30) return null;
  return switch (days) {
    0 => 'Birthday today!',
    1 => 'Birthday tomorrow',
    _ => 'Birthday in $days days',
  };
}
