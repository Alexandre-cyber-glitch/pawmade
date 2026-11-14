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
}
