import 'living_labels.dart';

/// Version complète d'un living, renvoyée par `GET /api/living/{id}`.
/// Correspond à `DogDetail` ou `PlantDetail` côté back (champ `type`).
class LivingDetail {
  final int id;
  final String name;
  final String type;

  /// Image du cercle (petite, carrée).
  final String? avatarUrl;

  /// Grande image de la carte (format paysage).
  final String? coverUrl;

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
    this.avatarUrl,
    this.coverUrl,
    this.birthDate,
    this.sex,
    this.weight,
    this.breed,
    this.species,
    this.acquisitionDate,
    this.wateringFrequencyDays,
  });

  factory LivingDetail.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final raw = readString(json, key);
      return raw == null ? null : DateTime.tryParse(raw);
    }

    final legacyPhoto = readString(json, 'photoUrl'); // ancien champ

    return LivingDetail(
      id: (json['id'] as num).toInt(),
      name: readString(json, 'name') ?? '',
      type: readString(json, 'type') ?? '',
      avatarUrl: readString(json, 'avatarUrl') ?? legacyPhoto,
      coverUrl: readString(json, 'coverUrl') ?? legacyPhoto,
      birthDate: date('birthDate'),
      sex: readString(json, 'sex'),
      weight: (json['weight'] as num?)?.toDouble(),
      breed: readString(json, 'breed'),
      species: readString(json, 'species'),
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
