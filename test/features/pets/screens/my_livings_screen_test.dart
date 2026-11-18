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
  Future<LivingDetail> Function(int id) onFindById = (id) async =>
      details[id]!;

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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    list.complete(summaries);
    await tester.pumpAndSettle();

    expect(find.text('My Pets'), findsOneWidget);
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

  testWidgets('liste vide : message', (tester) async {
    final api = FakeScreenApi()..onFindAll = () async => [];
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Aucun élément enregistré.'), findsOneWidget);
    expect(api.findByIdCalls, isEmpty);
  });

  testWidgets('erreur de liste : bouton Réessayer qui relance', (
    tester,
  ) async {
    final api = FakeScreenApi()
      ..onFindAll = () async => throw const ApiException('down');
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger tes éléments.'), findsOneWidget);

    api.onFindAll = () async => summaries;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(api.findAllCalls, 2);
    expect(cardText('Warm Waffle'), findsOneWidget);
  });

  testWidgets('erreur de détail : message + Réessayer, cercles visibles', (
    tester,
  ) async {
    final api = FakeScreenApi()
      ..onFindById = (_) async => throw const ApiException('down');
    await pumpScreen(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger le détail.'), findsOneWidget);
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
}
