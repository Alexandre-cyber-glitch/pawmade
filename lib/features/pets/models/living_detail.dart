import 'living_labels.dart';

/// Version complète d'un living, renvoyée par `GET /api/living/{id}`.
/// Correspond à `DogDetail` ou `PlantDetail` côté back (champ `type`).
class LivingDetail {
  final int id;
  final String name;
  final String? photoUrl;
  final String type;

  // Animal / Dog
  final DateTime? birthDate;
  final String? sex;
  final double? weight;
  final String? breed;

  // Plant
  final String? species;
  final DateTime? acquisitionDate;
  final int? wateringFrequencyDays;

  const LivingDetail({
    required this.id,
    required this.name,
    required this.type,
    this.photoUrl,
    this.birthDate,
    this.sex,
    this.weight,
    this.breed,
    this.species,
    this.acquisitionDate,
    this.wateringFrequencyDays,
  });

  factory LivingDetail.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] != null ? DateTime.parse(json[key] as String) : null;

    return LivingDetail(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      photoUrl: json['photoUrl'] as String?,
      birthDate: date('birthDate'),
      sex: json['sex'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      breed: json['breed'] as String?,
      species: json['species'] as String?,
      acquisitionDate: date('acquisitionDate'),
      wateringFrequencyDays: (json['wateringFrequencyDays'] as num?)?.toInt(),
    );
  }

  bool get isDog => type == 'DOG';

  bool get isPlant => type == 'PLANT';

  // ---------- Libellés d'affichage ----------

  /// "DOG" -> "Dog"
  String get typeLabel => humanizeEnum(type);

  /// "GOLDEN_RETRIEVER" -> "Golden Retriever"
  String? get breedLabel => breed == null ? null : humanizeEnum(breed!);

  /// "MALE" -> "Male"
  String? get sexLabel => sex == null ? null : humanizeEnum(sex!);

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
}
