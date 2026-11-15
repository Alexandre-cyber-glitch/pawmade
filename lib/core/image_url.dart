import 'api_config.dart';

/// Transforme ce que le back renvoie en URL d'image utilisable,
/// ou `null` si la valeur est vide / invalide (=> le widget affiche un fallback).
///
/// - `null`, `""`, `"   "`                       -> null
/// - `"/images/avatar/warm-waffle.jpg"`          -> baseUrl + chemin
/// - `"images/avatar/warm-waffle.jpg"`           -> baseUrl + "/" + chemin
/// - `"https://images.unsplash.com/…"`           -> inchangée
/// - `"n'importe quoi"`, `"nimp"`, `"ftp://…"`, `"http://"` -> null
String? resolveImageUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final String candidate;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    candidate = value;
  } else if (value.contains('://') ||
      value.contains(' ') ||
      !value.contains('/')) {
    // autre protocole, texte libre, ou mot seul sans dossier : on refuse
    return null;
  } else {
    final path = value.startsWith('/') ? value : '/$value';
    candidate = '${ApiConfig.baseUrl}$path';
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return uri.toString();
}
