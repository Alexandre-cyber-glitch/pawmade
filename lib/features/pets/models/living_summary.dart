import 'living_labels.dart';

/// Version légère d'un living, renvoyée par `GET /api/living`.
/// Sert uniquement à afficher les cercles (stories).
class LivingSummary {
  final int id;
  final String name;
  final String type;

  /// Image du cercle (petite, carrée).
  final String? avatarUrl;

  const LivingSummary({
    required this.id,
    required this.name,
    required this.type,
    this.avatarUrl,
  });

  factory LivingSummary.fromJson(Map<String, dynamic> json) {
    return LivingSummary(
      id: (json['id'] as num).toInt(),
      name: readString(json, 'name') ?? '',
      type: readString(json, 'type') ?? '',
      // `avatarUrl` côté back ; `photoUrl` gardé en secours (ancien champ).
      avatarUrl: readString(json, 'avatarUrl') ?? readString(json, 'photoUrl'),
    );
  }

  bool get isPlant => type == 'PLANT';

  /// "DOG" -> "Dog"
  String get typeLabel => humanizeEnum(type);
}
