import 'living_labels.dart';

/// Version légère d'un living, renvoyée par `GET /api/living`.
/// Sert uniquement à afficher les cercles (stories).
class LivingSummary {
  final int id;
  final String name;
  final String? photoUrl;
  final String type;

  const LivingSummary({
    required this.id,
    required this.name,
    required this.type,
    this.photoUrl,
  });

  factory LivingSummary.fromJson(Map<String, dynamic> json) {
    return LivingSummary(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  bool get isPlant => type == 'PLANT';

  /// "DOG" -> "Dog"
  String get typeLabel => humanizeEnum(type);
}
