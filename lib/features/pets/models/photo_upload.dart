/// Réponse de `POST /api/living/{id}/photos` (PhotoResponse côté back).
class PhotoUpload {
  final String id;
  final String? url;

  const PhotoUpload({required this.id, this.url});

  factory PhotoUpload.fromJson(Map<String, dynamic> json) => PhotoUpload(
    id: json['id'] as String,
    url: json['url'] is String ? json['url'] as String : null,
  );
}

/// Emplacement d'une photo sur un living.
enum PhotoSlot {
  avatar('avatar'),
  cover('cover');

  /// Segment d'URL : `PUT /api/living/{id}/avatar` ou `/cover`.
  final String path;

  const PhotoSlot(this.path);
}
