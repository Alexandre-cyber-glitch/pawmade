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
