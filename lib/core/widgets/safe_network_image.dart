import 'package:flutter/material.dart';

import '../image_url.dart';

/// `Image.network` qui ne casse jamais :
/// URL nulle, vide, invalide, 404, pas une image, CORS bloqué…
/// -> on affiche [fallback] à la place.
///
/// [urls] : liste de candidates essayées dans l'ordre
/// (ex. cover puis avatar). La première URL valide est utilisée.
class SafeNetworkImage extends StatelessWidget {
  final List<String?> urls;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;

  const SafeNetworkImage({
    super.key,
    required this.urls,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = urls.map(resolveImageUrl).whereType<String>().toList();
    return _build(resolved, 0);
  }

  Widget _build(List<String> resolved, int index) {
    if (index >= resolved.length) return fallback;

    return Image.network(
      resolved[index],
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      // Tant que la première image n'est pas décodée : fallback.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          (frame == null && !wasSynchronouslyLoaded) ? fallback : child,
      // Échec de chargement : on tente l'URL suivante, sinon fallback.
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image KO (${resolved[index]}) : $error');
        return _build(resolved, index + 1);
      },
    );
  }
}
