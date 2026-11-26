import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawmade/core/api_exception.dart';
import 'package:pawmade/features/pets/models/living_detail.dart';
import 'package:pawmade/features/pets/models/photo_upload.dart';
import 'package:pawmade/features/pets/models/update_living_request.dart';
import 'package:pawmade/features/pets/service/living_api.dart';
import 'package:pawmade/features/pets/widgets/edit/edit_form_fields.dart';
import 'package:pawmade/features/pets/widgets/edit/edit_living_sheet.dart';

/// Fausse API : enregistre la requête reçue, renvoie un résultat ou une erreur.
class FakeLivingApi extends LivingApi {
  UpdateLivingRequest? lastRequest;
  ApiException? errorToThrow;

  PhotoSlot? lastSlot;
  List<int>? lastBytes;
  String? lastFilename;

  @override
  Future<LivingDetail> update(int id, UpdateLivingRequest request) async {
    lastRequest = request;
    if (errorToThrow != null) throw errorToThrow!;
    final json = request.toJson();
    return LivingDetail.fromJson({...json, 'id': id});
  }

  @override
  Future<LivingDetail> changePhoto(
    int livingId,
    PhotoSlot slot, {
    required List<int> bytes,
    required String filename,
  }) async {
    lastSlot = slot;
    lastBytes = bytes;
    lastFilename = filename;
    if (errorToThrow != null) throw errorToThrow!;
    const newUrl = '/api/photos/new-photo/content';
    return LivingDetail(
      id: livingId,
      name: dog.name,
      type: dog.type,
      avatarUrl: slot == PhotoSlot.avatar ? newUrl : dog.avatarUrl,
      coverUrl: slot == PhotoSlot.cover ? newUrl : dog.coverUrl,
    );
  }
}

/// Sélecteur d'image factice (pas de vraie galerie en test).
PickImage fakePicker(XFile? file) =>
    () async => file;

final pickedFile = XFile.fromData(
  Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
  name: 'dog.jpg',
  path: 'dog.jpg', // le vrai picker fournit toujours un chemin
);

final dog = LivingDetail(
  id: 1,
  name: 'Warm Waffle',
  type: 'DOG',
  avatarUrl: '/api/photos/00000000-0000-0000-0000-000000000001/content',
  coverUrl: '/api/photos/00000000-0000-0000-0000-000000000002/content',
  birthDate: DateTime(2025, 6, 15),
  sex: 'MALE',
  weight: 12.5,
  breed: 'GOLDEN_RETRIEVER',
);

/// Écran minimal avec un bouton qui ouvre le bloc et mémorise le résultat.
Future<List<LivingDetail?>> pumpHost(
  WidgetTester tester,
  FakeLivingApi api,
  LivingDetail living, {
  PickImage? pickImage,
  CropImage? cropImage,
  ValueChanged<LivingDetail>? onPhotoChanged,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final results = <LivingDetail?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => results.add(
                await showEditLivingSheet(
                  context,
                  living: living,
                  api: api,
                  pickImage: pickImage ?? fakePicker(null),
                  // Par défaut : recadrage "transparent" (renvoie l'image telle quelle).
                  cropImage: cropImage ?? (_, bytes, _) async => bytes,
                  onPhotoChanged: onPhotoChanged,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('validateurs (mêmes règles que le back)', () {
    test('name', () {
      expect(validateName(''), isNotNull);
      expect(validateName('   '), isNotNull);
      expect(validateName('a' * 51), isNotNull);
      expect(validateName('Buddy'), isNull);
    });
    test('weight', () {
      expect(validateWeight(''), isNull);
      expect(validateWeight('12,5'), isNull);
      expect(validateWeight('0'), isNotNull);
      expect(validateWeight('-3'), isNotNull);
      expect(validateWeight('1000'), isNotNull);
      expect(validateWeight('12.345'), isNotNull);
    });
    test('watering', () {
      expect(validateWateringDays('7'), isNull);
      expect(validateWateringDays('0'), isNotNull);
      expect(validateWateringDays('366'), isNotNull);
    });
  });

  test('toJson : format attendu par le back', () {
    final json = UpdateDogRequest(
      name: 'Buddy',
      birthDate: DateTime(2025, 6, 5),
      weight: 12.5,
    ).toJson();
    expect(json['type'], 'DOG');
    expect(json['birthDate'], '2025-06-05');
    expect(json['weight'], 12.5);
    expect(json.containsKey('sex'), isTrue); // null explicite (PUT)
    // Les URLs de photos sont calculées par le back : jamais envoyées.
    expect(json.containsKey('avatarUrl'), isFalse);
    expect(json.containsKey('coverUrl'), isFalse);
  });

  testWidgets('préremplit, envoie les modifs et renvoie le détail à jour', (
    tester,
  ) async {
    final api = FakeLivingApi();
    final results = await pumpHost(tester, api, dog);

    expect(find.text('Edit Warm Waffle'), findsOneWidget);
    expect(find.text('Warm Waffle'), findsOneWidget); // champ Name prérempli
    expect(find.text('12.5'), findsOneWidget); // poids prérempli

    // Plus de champs URL : les photos ne s'éditent pas ici.
    expect(find.textContaining('URL'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Buddy');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final req = api.lastRequest as UpdateDogRequest;
    expect(req.name, 'Buddy');
    expect(req.breed, 'GOLDEN_RETRIEVER');
    expect(req.weight, 12.5);

    expect(find.text('Save changes'), findsNothing); // bloc fermé
    expect(results.single?.name, 'Buddy');
  });

  testWidgets('nom vide : pas d\'appel API, erreur affichée', (tester) async {
    final api = FakeLivingApi();
    await pumpHost(tester, api, dog);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(api.lastRequest, isNull);
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget); // reste ouvert
  });

  testWidgets('erreur back : message affiché, le bloc reste ouvert', (
    tester,
  ) async {
    final api = FakeLivingApi()
      ..errorToThrow = const ApiException('Living 1 is a DOG, mismatch');
    final results = await pumpHost(tester, api, dog);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Living 1 is a DOG, mismatch'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(results, isEmpty);
  });

  group('changement de photo', () {
    testWidgets('avatar : galerie -> upload -> écran prévenu', (tester) async {
      final api = FakeLivingApi();
      final changed = <LivingDetail>[];
      await pumpHost(
        tester,
        api,
        dog,
        pickImage: fakePicker(pickedFile),
        onPhotoChanged: changed.add,
      );

      await tester.tap(find.byTooltip('Change avatar'));
      await tester.pumpAndSettle();

      expect(api.lastSlot, PhotoSlot.avatar);
      expect(api.lastBytes, [0xFF, 0xD8, 0xFF, 0xE0]);
      expect(api.lastFilename, 'dog.jpg');
      expect(changed.single.avatarUrl, '/api/photos/new-photo/content');
      expect(changed.single.coverUrl, dog.coverUrl); // cover inchangée
      expect(find.text('Save changes'), findsOneWidget); // bloc reste ouvert
    });

    testWidgets('cover : bon emplacement envoyé', (tester) async {
      final api = FakeLivingApi();
      final changed = <LivingDetail>[];
      await pumpHost(
        tester,
        api,
        dog,
        pickImage: fakePicker(pickedFile),
        onPhotoChanged: changed.add,
      );

      await tester.tap(find.text('Change cover'));
      await tester.pumpAndSettle();

      expect(api.lastSlot, PhotoSlot.cover);
      expect(changed.single.coverUrl, '/api/photos/new-photo/content');
    });

    testWidgets("recadrage : l'image recadrée part au back", (tester) async {
      final api = FakeLivingApi();
      PhotoSlot? croppedSlot;
      await pumpHost(
        tester,
        api,
        dog,
        pickImage: fakePicker(
          XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            name: 'IMG_42.HEIC',
            path: 'IMG_42.HEIC',
          ),
        ),
        cropImage: (_, bytes, slot) async {
          croppedSlot = slot;
          expect(bytes, [1, 2, 3]); // reçoit bien l'image choisie
          return Uint8List.fromList([9, 9]);
        },
      );

      await tester.tap(find.text('Change cover'));
      await tester.pumpAndSettle();

      expect(croppedSlot, PhotoSlot.cover);
      expect(api.lastBytes, [9, 9]);
      expect(api.lastFilename, 'IMG_42.jpg'); // toujours un JPEG
    });

    testWidgets("recadrage annulé : rien n'est envoyé", (tester) async {
      final api = FakeLivingApi();
      final changed = <LivingDetail>[];
      await pumpHost(
        tester,
        api,
        dog,
        pickImage: fakePicker(pickedFile),
        cropImage: (_, _, _) async => null,
        onPhotoChanged: changed.add,
      );

      await tester.tap(find.byTooltip('Change avatar'));
      await tester.pumpAndSettle();

      expect(api.lastSlot, isNull);
      expect(changed, isEmpty);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('galerie annulée : aucun appel', (tester) async {
      final api = FakeLivingApi();
      final changed = <LivingDetail>[];
      await pumpHost(tester, api, dog, onPhotoChanged: changed.add);

      await tester.tap(find.text('Change cover'));
      await tester.pumpAndSettle();

      expect(api.lastSlot, isNull);
      expect(changed, isEmpty);
    });

    testWidgets('erreur back : message affiché, écran non prévenu', (
      tester,
    ) async {
      final api = FakeLivingApi()
        ..errorToThrow = const ApiException(
          'Only JPEG, PNG or WEBP images are accepted',
        );
      final changed = <LivingDetail>[];
      await pumpHost(
        tester,
        api,
        dog,
        pickImage: fakePicker(pickedFile),
        onPhotoChanged: changed.add,
      );

      await tester.tap(find.byTooltip('Change avatar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Only JPEG, PNG or WEBP images are accepted'),
        findsOneWidget,
      );
      expect(changed, isEmpty);
    });
  });

  testWidgets('plante : champs plante, pas de champs chien', (tester) async {
    final api = FakeLivingApi();
    await pumpHost(
      tester,
      api,
      const LivingDetail(
        id: 2,
        name: 'Albert',
        type: 'PLANT',
        species: 'Monstera Deliciosa',
        wateringFrequencyDays: 7,
      ),
    );

    expect(find.text('Species'), findsOneWidget);
    expect(find.text('Watering every'), findsOneWidget);
    expect(find.text('Breed'), findsNothing);
    expect(find.text('Weight'), findsNothing);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final req = api.lastRequest as UpdatePlantRequest;
    expect(req.toJson()['type'], 'PLANT');
    expect(req.wateringFrequencyDays, 7);
  });
}
