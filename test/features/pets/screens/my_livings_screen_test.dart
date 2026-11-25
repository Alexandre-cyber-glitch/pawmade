import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmade/core/api_exception.dart';
import 'package:pawmade/features/pets/models/living_detail.dart';
import 'package:pawmade/features/pets/models/living_summary.dart';
import 'package:pawmade/features/pets/models/update_living_request.dart';
import 'package:pawmade/features/pets/screens/my_livings_screen.dart';
import 'package:pawmade/features/pets/service/living_api.dart';
import 'package:pawmade/features/pets/widgets/living_avatar_item.dart';
import 'package:pawmade/features/pets/widgets/living_detail_card.dart';

const summaries = [
  LivingSummary(id: 1, name: 'Warm Waffle', type: 'DOG'),
  LivingSummary(id: 2, name: 'Albert', type: 'PLANT'),
];

final details = {
  1: LivingDetail(
    id: 1,
    name: 'Warm Waffle',
    type: 'DOG',
    breed: 'GOLDEN_RETRIEVER',
    sex: 'MALE',
    weight: 12.5,
    birthDate: DateTime(2025, 6, 15),
  ),
  2: const LivingDetail(
    id: 2,
    name: 'Albert',
    type: 'PLANT',
    species: 'Monstera Deliciosa',
    wateringFrequencyDays: 7,
  ),
};

/// Fausse API pilotable : on choisit ce que renvoie chaque appel
/// et on compte les appels.
class FakeScreenApi extends LivingApi {
  Future<List<LivingSummary>> Function() onFindAll = () async => summaries;
  Future<LivingDetail> Function(int id) onFindById = (id) async => details[id]!;

  int findAllCalls = 0;
  final findByIdCalls = <int>[];

  @override
  Future<List<LivingSummary>> findAll() {
    findAllCalls++;
    return onFindAll();
  }

  @override
  Future<LivingDetail> findById(int id) {
    findByIdCalls.add(id);
    return onFindById(id);
  }

  @override
  Future<LivingDetail> update(int id, UpdateLivingRequest request) async {
    final json = request.toJson();
    return LivingDetail.fromJson({...json, 'id': id});
  }
}

Future<void> pumpScreen(WidgetTester tester, FakeScreenApi api) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: MyLivingsScreen(api: api)));
}

/// Texte affiché sur la carte du milieu.
Finder cardText(String text) => find.descendant(
  of: find.byType(LivingDetailCard),
  matching: find.text(text),
);

/// Cercle (story) d'un living.
Finder circle(String name) => find.descendant(
  of: find.byType(LivingAvatarItem),
  matching: find.text(name),
);

void main() {
  testWidgets('chargement puis cercles + détail du premier', (tester) async {
    final api = FakeScreenApi();
    final list = Completer<List<LivingSummary>>();
    api.onFindAll = () => list.future;

    await pumpScreen(tester, api);
    // Template pendant le chargement : en-tête, 3 cercles fantômes,
    // bouton Add Pet, carte vide avec loader.
    expect(find.text('My Pets'), findsOneWidget);
    expect(find.byType(PlaceholderAvatar), findsNWidgets(3));
    expect(find.byType(AddLivingAvatar, skipOffstage: false), findsOneWidget);
    expect(find.byType(LivingDetailCardSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    list.complete(summaries);
    await tester.pumpAndSettle();

    expect(find.byType(PlaceholderAvatar), findsNothing);
    expect(circle('Albert'), findsOneWidget);
    expect(api.findByIdCalls, [1]); // seul le sélectionné est chargé
    expect(cardText('Warm Waffle'), findsOneWidget);
    expect(cardText('Golden Retriever'), findsOneWidget);
  });

  testWidgets('clic sur un cercle : recharge le détail de ce living', (
    tester,
  ) async {
    final api = FakeScreenApi();
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    await tester.tap(circle('Albert'));
    await tester.pumpAndSettle();

    expect(api.findByIdCalls, [1, 2]);
    expect(cardText('Monstera Deliciosa'), findsOneWidget);
    expect(cardText('Every 7 days'), findsOneWidget);

    // Re-cliquer refait un appel : infos toujours à jour.
    await tester.tap(circle('Albert'));
    await tester.pumpAndSettle();
    expect(api.findByIdCalls, [1, 2, 2]);
  });

  testWidgets('liste vide : template avec Add Pet + message', (tester) async {
    final api = FakeScreenApi()..onFindAll = () async => [];
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('My Pets'), findsOneWidget);
    expect(find.byType(AddLivingAvatar), findsOneWidget);
    expect(find.text('Aucun compagnon pour l\'instant'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing); // rien à réessayer
    expect(api.findByIdCalls, isEmpty);
  });

  testWidgets('serveur injoignable : template + Réessayer qui relance', (
    tester,
  ) async {
    final api = FakeScreenApi()
      ..onFindAll = () async => throw const ApiException('down');
    await pumpScreen(tester, api);
    await tester.pumpAndSettle(); // pas d'animation infinie hors ligne

    // La mise en page reste là : en-tête, cercles fantômes, carte vide.
    expect(find.text('My Pets'), findsOneWidget);
    expect(find.byType(PlaceholderAvatar), findsNWidgets(3));
    expect(find.byType(AddLivingAvatar, skipOffstage: false), findsOneWidget);
    expect(find.text('Impossible de joindre le serveur'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    api.onFindAll = () async => summaries;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(api.findAllCalls, 2);
    expect(find.byType(PlaceholderAvatar), findsNothing);
    expect(cardText('Warm Waffle'), findsOneWidget);
  });

  testWidgets('serveur injoignable : tirer vers le bas relance aussi', (
    tester,
  ) async {
    final api = FakeScreenApi()
      ..onFindAll = () async => throw const ApiException('down');
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    api.onFindAll = () async => summaries;
    await tester.fling(find.text('My Pets'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(api.findAllCalls, 2);
    expect(circle('Albert'), findsOneWidget);
  });

  testWidgets('erreur de détail : message + Réessayer, cercles visibles', (
    tester,
  ) async {
    final api = FakeScreenApi()
      ..onFindById = (_) async => throw const ApiException('down');
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger le détail'), findsOneWidget);
    expect(find.byType(LivingDetailCardSkeleton), findsOneWidget);
    expect(circle('Albert'), findsOneWidget);

    api.onFindById = (id) async => details[id]!;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(cardText('Warm Waffle'), findsOneWidget);
  });

  testWidgets('édition : carte et cercle mis à jour sans recharger', (
    tester,
  ) async {
    final api = FakeScreenApi();
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Warm Waffle'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Buddy');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Save changes'), findsNothing); // bloc fermé
    expect(cardText('Buddy'), findsOneWidget);
    expect(find.text('Buddy'), findsNWidgets(2)); // carte + cercle
    expect(find.text('Warm Waffle'), findsNothing);
    expect(find.text('Buddy updated'), findsOneWidget); // SnackBar
    expect(api.findAllCalls, 1); // pas de rechargement réseau
    expect(api.findByIdCalls, [1]);
  });

  group('swipe sur la carte', () {
    const left = Offset(-200, 0);
    const right = Offset(200, 0);

    testWidgets('gauche -> suivant, droite -> précédent', (tester) async {
      final api = FakeScreenApi();
      await pumpScreen(tester, api);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(LivingDetailCard), left, 1000);
      await tester.pumpAndSettle();
      expect(cardText('Albert'), findsOneWidget);

      await tester.fling(find.byType(LivingDetailCard), right, 1000);
      await tester.pumpAndSettle();
      expect(cardText('Warm Waffle'), findsOneWidget);
      expect(api.findByIdCalls, [1, 2, 1]);
    });

    testWidgets('aux extrémités : rien ne se passe', (tester) async {
      final api = FakeScreenApi();
      await pumpScreen(tester, api);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(LivingDetailCard), right, 1000);
      await tester.pumpAndSettle();
      expect(api.findByIdCalls, [1]);

      await tester.fling(find.byType(LivingDetailCard), left, 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(LivingDetailCard), left, 1000);
      await tester.pumpAndSettle();
      expect(api.findByIdCalls, [1, 2]);
    });

    testWidgets('glissement lent : long accepté, court ignoré', (tester) async {
      final api = FakeScreenApi();
      await pumpScreen(tester, api);
      await tester.pumpAndSettle();

      Future<void> slowDrag(double dx) async {
        await tester.timedDrag(
          find.byType(LivingDetailCard),
          Offset(dx, 0),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
      }

      await slowDrag(-50);
      expect(api.findByIdCalls, [1]);
      await slowDrag(-200);
      expect(api.findByIdCalls, [1, 2]);
    });

    testWidgets('la rangée défile pour montrer le cercle choisi', (
      tester,
    ) async {
      final many = [
        for (var i = 1; i <= 6; i++)
          LivingSummary(id: i, name: 'Pet $i', type: 'DOG'),
      ];
      final api = FakeScreenApi()
        ..onFindAll = (() async => many)
        ..onFindById = (id) async =>
            LivingDetail(id: id, name: 'Pet $id', type: 'DOG');
      await pumpScreen(tester, api);
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        await tester.fling(find.byType(LivingDetailCard), left, 1000);
        await tester.pumpAndSettle();
      }

      expect(cardText('Pet 6'), findsOneWidget);
      expect(circle('Pet 6').hitTestable(), findsOneWidget); // bien visible
    });
  });
}
