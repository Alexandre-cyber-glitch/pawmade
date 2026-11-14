class LivingItem {
  final int id;
  final String name;
  final String? photoUrl;
  final String type;

  final String? breed;
  final DateTime? birthDate;
  final String? sex;
  final double? weight;

  final String? species;
  final DateTime? acquisitionDate;
  final int? wateringFrequencyDays;

  const LivingItem({
    required this.id,
    required this.name,
    required this.type,
    this.photoUrl,
    this.breed,
    this.birthDate,
    this.sex,
    this.weight,
    this.species,
    this.acquisitionDate,
    this.wateringFrequencyDays,
  });

  factory LivingItem.fromJson(Map<String, dynamic> json) {
    return LivingItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      photoUrl: json['photoUrl'] as String?,

      // Dog
      breed: json['breed'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      sex: json['sex'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),

      // Plant
      species: json['species'] as String?,
      acquisitionDate: json['acquisitionDate'] != null
          ? DateTime.parse(json['acquisitionDate'] as String)
          : null,
      wateringFrequencyDays: (json['wateringFrequencyDays'] as num?)?.toInt(),
    );
  }

  bool get isDog => type == 'DOG';

  bool get isPlant => type == 'PLANT';

  // ---------- Libellés d'affichage ----------

  /// "DOG" -> "Dog"
  String get typeLabel => _humanize(type);

  /// "GOLDEN_RETRIVEVER" -> "Golden Retriever"
  String? get breedLabel {
    if (breed == null) return null;
    const fixes = {
      'GOLDEN_RETRIVEVER': 'Golden Retriever',
      'GERMAN_SHEPARD': 'German Shepherd',
    };
    return fixes[breed] ?? _humanize(breed!);
  }

  /// "MALE" -> "Male"
  String? get sexLabel => sex == null ? null : _humanize(sex!);

  /// "3 Years", "1 Year", "5 Months"
  String? get ageLabel {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var months =
        (now.year - birthDate!.year) * 12 + now.month - birthDate!.month;
    if (now.day < birthDate!.day) months--;
    if (months < 0) months = 0;

    if (months < 12) return '$months ${months == 1 ? 'Month' : 'Months'}';
    final years = months ~/ 12;
    return '$years ${years == 1 ? 'Year' : 'Years'}';
  }

  /// 12.5 -> "12.5 kg", 28.0 -> "28 kg"
  String? get weightLabel {
    if (weight == null) return null;
    final w = weight!;
    final text = w == w.roundToDouble()
        ? w.toStringAsFixed(0)
        : w.toStringAsFixed(1);
    return '$text kg';
  }

  static String _humanize(String value) => value
      .toLowerCase()
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
