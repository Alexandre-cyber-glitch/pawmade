import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../../models/photo_upload.dart';

// =====================================================================
// Calculs du recadrage (sans UI, testables à part).
// =====================================================================

/// Format du cadre : la cover suit la carte (≈ 2:1), l'avatar est carré
/// (affiché en rond).
double cropAspectRatio(PhotoSlot slot) => slot == PhotoSlot.cover ? 2 : 1;

/// Largeur max du fichier envoyé : assez pour un écran de téléphone,
/// sans envoyer des Mo pour rien.
int cropMaxWidth(PhotoSlot slot) => slot == PhotoSlot.cover ? 1600 : 800;

/// Échelle de départ pour que l'image remplisse tout le cadre
/// (comme `BoxFit.cover`).
double coverScale(Size image, Size frame) =>
    math.max(frame.width / image.width, frame.height / image.height);

/// Zone de l'image (en pixels de l'image) visible dans le cadre.
///
/// L'image est affichée à `coverScale` puis déplacée / zoomée par
/// l'utilisateur ([transform] de l'InteractiveViewer). On fait le chemin
/// inverse : coin haut-gauche du cadre -> coordonnées dans l'image.
Rect visibleImageRect({
  required Size image,
  required Size frame,
  required Matrix4 transform,
}) {
  final scale = coverScale(image, frame) * transform.getMaxScaleOnAxis();
  final translation = transform.getTranslation();
  final rect = Rect.fromLTWH(
    -translation.x / scale,
    -translation.y / scale,
    frame.width / scale,
    frame.height / scale,
  );
  return rect.intersect(Offset.zero & image);
}

/// Translation qui centre l'image (affichée à `coverScale`) dans le cadre.
Matrix4 centeredTransform(Size image, Size frame) {
  final scale = coverScale(image, frame);
  return Matrix4.translationValues(
    (frame.width - image.width * scale) / 2,
    (frame.height - image.height * scale) / 2,
    0,
  );
}

// =====================================================================
// Découpe réelle du fichier.
// =====================================================================

/// Découpe [rect] dans l'image, la réduit à [maxWidth] et la ré-encode
/// en JPEG (format accepté par le back).
///
/// [displayedSize] = taille de l'image telle qu'affichée par Flutter :
/// si le décodeur trouve une autre taille, le rectangle est remis
/// à l'échelle.
///
/// Fait dans un isolate séparé (sur mobile) pour ne pas figer l'écran.
Future<Uint8List> cropToJpeg(
  Uint8List bytes, {
  required Rect rect,
  required Size displayedSize,
  required int maxWidth,
}) {
  return compute(
    cropToJpegSync,
    CropJob(
      bytes: bytes,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      displayedWidth: displayedSize.width,
      displayedHeight: displayedSize.height,
      maxWidth: maxWidth,
    ),
  );
}

/// Données envoyées à l'isolate (types simples uniquement).
class CropJob {
  final Uint8List bytes;
  final double left;
  final double top;
  final double width;
  final double height;
  final double displayedWidth;
  final double displayedHeight;
  final int maxWidth;

  const CropJob({
    required this.bytes,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.displayedWidth,
    required this.displayedHeight,
    required this.maxWidth,
  });
}

@visibleForTesting
Uint8List cropToJpegSync(CropJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported image format');
  }
  // Applique la rotation EXIF (photos de téléphone) pour travailler
  // sur l'image "à l'endroit", comme Flutter l'affiche.
  final image = img.bakeOrientation(decoded);

  final sx = image.width / job.displayedWidth;
  final sy = image.height / job.displayedHeight;
  final x = (job.left * sx).round().clamp(0, image.width - 1);
  final y = (job.top * sy).round().clamp(0, image.height - 1);
  final w = (job.width * sx).round().clamp(1, image.width - x);
  final h = (job.height * sy).round().clamp(1, image.height - y);

  var result = img.copyCrop(image, x: x, y: y, width: w, height: h);
  if (result.width > job.maxWidth) {
    result = img.copyResize(
      result,
      width: job.maxWidth,
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(result, quality: 88);
}
