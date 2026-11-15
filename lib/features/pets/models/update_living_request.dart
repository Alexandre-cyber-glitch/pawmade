/// Corps du `PUT /api/living/{id}`.
/// Le champ `type` sert de discriminant côté back (@JsonTypeInfo).
sealed class UpdateLivingRequest {
  const UpdateLivingRequest();

  Map<String, dynamic> toJson();
}

class UpdateDogRequest extends UpdateLivingRequest {
  final String name;
  final DateTime? birthDate;
  final String? sex;
  final double? weight;
  final String? breed;
  final String? avatarUrl;
  final String? coverUrl;

  const UpdateDogRequest({
    required this.name,
    this.birthDate,
    this.sex,
    this.weight,
    this.breed,
    this.avatarUrl,
    this.coverUrl,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'DOG',
    'name': name,
    'birthDate': formatApiDate(birthDate),
    'sex': sex,
    'weight': weight,
    'breed': breed,
    'avatarUrl': avatarUrl,
    'coverUrl': coverUrl,
  };
}

class UpdatePlantRequest extends UpdateLivingRequest {
  final String name;
  final DateTime? acquisitionDate;
  final String? species;
  final int? wateringFrequencyDays;
  final String? avatarUrl;
  final String? coverUrl;

  const UpdatePlantRequest({
    required this.name,
    this.acquisitionDate,
    this.species,
    this.wateringFrequencyDays,
    this.avatarUrl,
    this.coverUrl,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'PLANT',
    'name': name,
    'acquisitionDate': formatApiDate(acquisitionDate),
    'species': species,
    'wateringFrequencyDays': wateringFrequencyDays,
    'avatarUrl': avatarUrl,
    'coverUrl': coverUrl,
  };
}

/// DateTime -> "2025-06-15" (format LocalDate attendu par le back).
String? formatApiDate(DateTime? d) {
  if (d == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}
