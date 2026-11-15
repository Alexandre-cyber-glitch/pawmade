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
