import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/paw_colors.dart';
import '../../models/photo_upload.dart';
import 'photo_crop.dart';

/// Ouvre l'écran de recadrage. Renvoie le JPEG recadré,
/// ou `null` si l'utilisateur annule.
Future<Uint8List?> showPhotoCropper(
  BuildContext context,
  Uint8List bytes,
  PhotoSlot slot,
) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoCropScreen(bytes: bytes, slot: slot),
    ),
  );
}

/// Plein écran noir avec un cadre au format de la carte (cover)
/// ou un rond (avatar). On déplace et on zoome la photo dedans :
/// ce qui est dans le cadre est exactement ce qui sera envoyé.
class PhotoCropScreen extends StatefulWidget {
  final Uint8List bytes;
  final PhotoSlot slot;

  const PhotoCropScreen({super.key, required this.bytes, required this.slot});

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _transform = TransformationController();

  /// Taille de l'image (lue sans l'afficher), null tant qu'on ne l'a pas.
  Size? _imageSize;

  /// Cadre pour lequel la position de départ a été calculée.
  Size? _initializedFor;

  bool _processing = false;
  String? _error;

  bool get _isAvatar => widget.slot == PhotoSlot.avatar;

  @override
  void initState() {
    super.initState();
    _readImageSize();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _readImageSize() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      if (mounted) setState(() => _imageSize = size);
    } catch (e) {
      debugPrint('Crop : image illisible : $e');
      if (mounted) setState(() => _error = 'This image cannot be read.');
    }
  }

  Future<void> _confirm(Size frame) async {
    final image = _imageSize;
    if (image == null || _processing) return;
    setState(() => _processing = true);
    try {
      final cropped = await cropToJpeg(
        widget.bytes,
        rect: visibleImageRect(
          image: image,
          frame: frame,
          transform: _transform.value,
        ),
        displayedSize: image,
        maxWidth: cropMaxWidth(widget.slot),
      );
      if (mounted) Navigator.of(context).pop(cropped);
    } catch (e) {
      debugPrint('Crop KO : $e');
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'This image cannot be cropped.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isAvatar ? 'Adjust avatar' : 'Adjust cover'),
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: _processing ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frame = _frameSize(constraints);
            return Column(
              children: [
                Expanded(child: Center(child: _buildFrame(frame))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _error ?? 'Drag to move · pinch or scroll to zoom',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _error != null ? PawColors.female : Colors.white70,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _imageSize == null || _processing
                          ? null
                          : () => _confirm(frame),
                      style: FilledButton.styleFrom(
                        backgroundColor: PawColors.caramel,
                        disabledBackgroundColor: PawColors.caramel.withValues(
                          alpha: 0.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _processing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Use photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Cadre le plus grand possible, au bon format, avec une marge.
  Size _frameSize(BoxConstraints constraints) {
    final ratio = cropAspectRatio(widget.slot);
    var width = constraints.maxWidth - 32;
    // On garde de la place pour le texte et le bouton en dessous.
    final maxHeight = (constraints.maxHeight - 140) * 0.9;
    if (width / ratio > maxHeight) width = maxHeight * ratio;
    return Size(width, width / ratio);
  }

  Widget _buildFrame(Size frame) {
    final image = _imageSize;
    if (image == null) {
      return SizedBox.fromSize(
        size: frame,
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: PawColors.caramel)
              : const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
        ),
      );
    }

    // Position de départ : image centrée et qui remplit le cadre.
    // (Recalculée si le cadre change de taille, ex. fenêtre web.)
    if (_initializedFor != frame) {
      final firstTime = _initializedFor == null;
      _initializedFor = frame;
      void reset() => _transform.value = centeredTransform(image, frame);
      if (firstTime) {
        reset();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => reset());
      }
    }

    final scale = coverScale(image, frame);
    return SizedBox.fromSize(
      size: frame,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            key: const ValueKey('crop_viewer'),
            transformationController: _transform,
            constrained: false,
            minScale: 1,
            maxScale: 5,
            // Pas de marge : la photo couvre toujours tout le cadre.
            boundaryMargin: EdgeInsets.zero,
            panEnabled: !_processing,
            scaleEnabled: !_processing,
            child: SizedBox(
              width: image.width * scale,
              height: image.height * scale,
              child: Image.memory(
                widget.bytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(painter: _FrameOverlay(circle: _isAvatar)),
          ),
        ],
      ),
    );
  }
}

/// Bordure du cadre + repères (tiers pour la cover, rond pour l'avatar).
class _FrameOverlay extends CustomPainter {
  final bool circle;

  _FrameOverlay({required this.circle});

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;

    if (circle) {
      // Assombrit les coins : seul le rond sera visible dans l'app.
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addOval(rect);
      canvas.drawPath(outside, Paint()..color = Colors.black54);
      canvas.drawOval(rect.deflate(1), border);
      return;
    }

    final guide = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guide);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }
    canvas.drawRect(rect.deflate(1), border);
  }

  @override
  bool shouldRepaint(covariant _FrameOverlay oldDelegate) =>
      oldDelegate.circle != circle;
}
