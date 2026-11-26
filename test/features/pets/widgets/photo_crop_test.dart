import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pawmade/features/pets/models/photo_upload.dart';
import 'package:pawmade/features/pets/widgets/edit/photo_crop.dart';
import 'package:pawmade/features/pets/widgets/edit/photo_crop_screen.dart';

/// Image de test : moitié haute rouge, moitié basse bleue.
Uint8List twoColorPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    final top = p.y < height / 2;
    p
      ..r = top ? 255 : 0
      ..g = 0
      ..b = top ? 0 : 255;
  }
  return img.encodePng(image);
}

CropJob job(
  Uint8List bytes, {
  required double left,
  required double top,
  required double width,
  required double height,
  required double displayedWidth,
  required double displayedHeight,
  int maxWidth = 1600,
}) => CropJob(
  bytes: bytes,
  left: left,
  top: top,
  width: width,
  height: height,
  displayedWidth: displayedWidth,
  displayedHeight: displayedHeight,
  maxWidth: maxWidth,
);

void main() {
  const portrait = Size(1000, 2000);
  const frame = Size(300, 150); // cadre 2:1 de la cover

  group('calculs', () {
    test('formats et tailles max par emplacement', () {
      expect(cropAspectRatio(PhotoSlot.cover), 2);
      expect(cropAspectRatio(PhotoSlot.avatar), 1);
      expect(cropMaxWidth(PhotoSlot.cover), 1600);
      expect(cropMaxWidth(PhotoSlot.avatar), 800);
    });

    test("coverScale : l'image remplit tout le cadre", () {
      expect(coverScale(portrait, frame), 0.3); // limité par la largeur
      expect(coverScale(const Size(4000, 1000), frame), 0.15); // la hauteur
    });

    test('position de départ : photo CENTRÉE, pas collée en haut', () {
      final rect = visibleImageRect(
        image: portrait,
        frame: frame,
        transform: centeredTransform(portrait, frame),
      );
      // Toute la largeur, et une bande de 500 px au milieu de la hauteur.
      expect(rect.left, closeTo(0, 0.001));
      expect(rect.width, closeTo(1000, 0.001));
      expect(rect.top, closeTo(750, 0.001));
      expect(rect.height, closeTo(500, 0.001));
    });

    test('photo remontée au maximum : on garde le bas', () {
      // Image affichée : 300 x 600 ; cadre : 150 de haut => -450.
      final rect = visibleImageRect(
        image: portrait,
        frame: frame,
        transform: Matrix4.translationValues(0, -450, 0),
      );
      expect(rect.top, closeTo(1500, 0.001));
      expect(rect.bottom, closeTo(2000, 0.001));
    });

    test('zoom x2 : zone deux fois plus petite', () {
      final rect = visibleImageRect(
        image: portrait,
        frame: frame,
        transform: Matrix4.diagonal3Values(2, 2, 1),
      );
      expect(rect.width, closeTo(500, 0.001));
      expect(rect.height, closeTo(250, 0.001));
    });

    test("ne sort jamais de l'image", () {
      final rect = visibleImageRect(
        image: portrait,
        frame: frame,
        transform: Matrix4.translationValues(200, 200, 0),
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
    });
  });

  group('découpe du fichier', () {
    test('découpe la bonne zone, sort un JPEG', () {
      final out = cropToJpegSync(
        job(
          twoColorPng(200, 400),
          left: 0,
          top: 300, // bas de l'image : partie bleue
          width: 200,
          height: 100,
          displayedWidth: 200,
          displayedHeight: 400,
        ),
      );

      expect(out.sublist(0, 3), [0xFF, 0xD8, 0xFF]); // signature JPEG
      final result = img.decodeJpg(out)!;
      expect(result.width, 200);
      expect(result.height, 100);
      final center = result.getPixel(100, 50);
      expect(center.b, greaterThan(200));
      expect(center.r, lessThan(50));
    });

    test('réduit à la largeur max en gardant les proportions', () {
      final out = cropToJpegSync(
        job(
          twoColorPng(2000, 1000),
          left: 0,
          top: 0,
          width: 2000,
          height: 1000,
          displayedWidth: 2000,
          displayedHeight: 1000,
          maxWidth: 800,
        ),
      );
      final result = img.decodeJpg(out)!;
      expect(result.width, 800);
      expect(result.height, 400);
    });

    test("taille affichée différente : rectangle remis à l'échelle", () {
      final out = cropToJpegSync(
        job(
          twoColorPng(400, 800),
          left: 0,
          top: 0,
          width: 100, // 100 px "affichés" = 200 vrais pixels
          height: 100,
          displayedWidth: 200,
          displayedHeight: 400,
        ),
      );
      expect(img.decodeJpg(out)!.width, 200);
    });

    test("fichier qui n'est pas une image : erreur claire", () {
      expect(
        () => cropToJpegSync(
          job(
            Uint8List.fromList([1, 2, 3]),
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            displayedWidth: 1,
            displayedHeight: 1,
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('écran de recadrage', () {
    /// Laisse tourner le vrai moteur (décodage d'image, isolate) jusqu'à
    /// ce que [done] soit vrai. Pas de pumpAndSettle : le loader tourne
    /// en boucle tant que l'image n'est pas prête.
    Future<void> waitFor(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 50 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(done(), isTrue, reason: 'délai dépassé');
    }

    bool viewerOrError() =>
        find.byKey(const ValueKey('crop_viewer')).evaluate().isNotEmpty ||
        find.byIcon(Icons.broken_image_outlined).evaluate().isNotEmpty;

    Future<List<Uint8List?>> openCropper(
      WidgetTester tester,
      Uint8List bytes,
      PhotoSlot slot,
    ) async {
      final results = <Uint8List?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async =>
                  results.add(await showPhotoCropper(context, bytes, slot)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // Animation d'ouverture (pas de pumpAndSettle : loader en boucle).
      await tester.pump(const Duration(milliseconds: 600));
      await waitFor(tester, viewerOrError);
      return results;
    }

    testWidgets('cover : cadre, bouton Use photo -> JPEG au format carte', (
      tester,
    ) async {
      final results = await openCropper(
        tester,
        twoColorPng(200, 400),
        PhotoSlot.cover,
      );

      expect(find.text('Adjust cover'), findsOneWidget);
      expect(find.byKey(const ValueKey('crop_viewer')), findsOneWidget);

      await tester.tap(find.text('Use photo'));
      await waitFor(tester, () => results.isNotEmpty);

      final result = img.decodeJpg(results.single!)!;
      expect(result.width / result.height, closeTo(2, 0.05));
    });

    testWidgets("fermer : rien n'est renvoyé", (tester) async {
      final results = await openCropper(
        tester,
        twoColorPng(100, 100),
        PhotoSlot.avatar,
      );
      expect(find.text('Adjust avatar'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('image illisible : message, bouton désactivé', (tester) async {
      await openCropper(tester, Uint8List.fromList([1, 2, 3]), PhotoSlot.cover);

      expect(find.text('This image cannot be read.'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}
