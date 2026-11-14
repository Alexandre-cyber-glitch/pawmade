/// "GOLDEN_RETRIEVER" -> "Golden Retriever"
String humanizeEnum(String value) => value
    .toLowerCase()
    .split('_')
    .where((p) => p.isNotEmpty)
    .map((p) => p[0].toUpperCase() + p.substring(1))
    .join(' ');
