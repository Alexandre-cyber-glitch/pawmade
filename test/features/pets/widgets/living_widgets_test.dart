import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmade/features/pets/models/living_detail.dart';
import 'package:pawmade/features/pets/models/living_summary.dart';
import 'package:pawmade/features/pets/widgets/living_avatar_item.dart';
import 'package:pawmade/features/pets/widgets/living_detail_card.dart';

Future<void> pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('LivingDetailCard', () {
    testWidgets('chien : nom, race, sexe, poids', (tester) async {
      await pump(
        tester,
        LivingDetailCard(
          living: LivingDetail(
            id: 1,
            name: 'Warm Waffle',
            type: 'DOG',
            sex: 'FEMALE',
            weight: 12.5,
            breed: 'GOLDEN_RETRIEVER',
            birthDate: DateTime(2020, 1, 1),
          ),
        ),
      );

      expect(find.text('Warm Waffle'), findsOneWidget);
      expect(find.text('Golden Retriever'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.byIcon(Icons.female), findsOneWidget);
      expect(find.text('12.5 kg'), findsOneWidget);
      expect(find.textContaining('Years'), findsOneWidget);
    });

    testWidgets('chien sans infos : valeurs de repli', (tester) async {
      await pump(
        tester,
        const LivingDetailCard(
          living: LivingDetail(id: 1, name: 'Enzo', type: 'DOG'),
        ),
      );
      expect(find.text('Dog'), findsOneWidget); // pas de race
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('- kg'), findsOneWidget);
    });

    testWidgets('plante : espèce, arrosage, date d\'acquisition', (
      tester,
    ) async {
      await pump(
        tester,
        LivingDetailCard(
          living: LivingDetail(
            id: 2,
            name: 'Albert',
            type: 'PLANT',
            species: 'Monstera Deliciosa',
            wateringFrequencyDays: 7,
            acquisitionDate: DateTime(2025, 8, 10),
          ),
        ),
      );
      expect(find.text('Monstera Deliciosa'), findsOneWidget);
      expect(find.text('Every 7 days'), findsOneWidget);
      expect(find.text('10/08/2025'), findsOneWidget);
      expect(find.byIcon(Icons.local_florist), findsOneWidget); // placeholder
    });

    testWidgets('puce anniversaire seulement quand il approche', (
      tester,
    ) async {
      final now = DateTime.now();
      Widget card(DateTime birth) => LivingDetailCard(
        living: LivingDetail(
          id: 1,
          name: 'Enzo',
          type: 'DOG',
          birthDate: birth,
        ),
      );

      await pump(tester, card(DateTime(now.year - 4, now.month, now.day + 5)));
      expect(find.byIcon(Icons.cake_outlined), findsOneWidget);
      expect(find.textContaining('Birthday'), findsOneWidget);

      await pump(tester, card(DateTime(now.year - 4, now.month + 4, now.day)));
      expect(find.byIcon(Icons.cake_outlined), findsNothing);
    });

    testWidgets('bouton Edit appelle onEdit', (tester) async {
      var taps = 0;
      await pump(
        tester,
        LivingDetailCard(
          living: const LivingDetail(id: 1, name: 'Enzo', type: 'DOG'),
          onEdit: () => taps++,
        ),
      );
      await tester.tap(find.text('Edit'));
      expect(taps, 1);
    });
  });

  group('LivingDetailCardSkeleton', () {
    testWidgets('par défaut : loader, pas de bouton', (tester) async {
      await pump(tester, const LivingDetailCardSkeleton());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    });

    testWidgets('avec message : icône, textes, Réessayer cliquable', (
      tester,
    ) async {
      var retries = 0;
      await pump(
        tester,
        LivingDetailCardSkeleton(
          message: 'Impossible de joindre le serveur',
          hint: 'Vérifie ta connexion',
          onRetry: () => retries++,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('Impossible de joindre le serveur'), findsOneWidget);
      expect(find.text('Vérifie ta connexion'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      expect(retries, 1);
    });
  });

  group('PlaceholderAvatar', () {
    testWidgets('statique : pas d\'animation en cours', (tester) async {
      await pump(tester, const PlaceholderAvatar());
      expect(find.byType(PlaceholderAvatar), findsOneWidget);
      // pumpAndSettle échouerait si une animation tournait en boucle.
      await tester.pumpAndSettle();
    });

    testWidgets('animate : pulse, puis s\'arrête quand animate passe à false', (
      tester,
    ) async {
      await pump(tester, const PlaceholderAvatar(animate: true));
      expect(tester.hasRunningAnimations, isTrue);

      await pump(tester, const PlaceholderAvatar());
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('LivingAvatarItem', () {
    testWidgets('affiche nom + type et réagit au tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        LivingAvatarItem(
          living: const LivingSummary(id: 1, name: 'Enzo', type: 'DOG'),
          isSelected: false,
          onTap: () => taps++,
        ),
      );
      expect(find.text('Enzo'), findsOneWidget);
      expect(find.text('Dog'), findsOneWidget);

      await tester.tap(find.text('Enzo'));
      expect(taps, 1);
    });

    testWidgets('AddLivingAvatar réagit au tap', (tester) async {
      var taps = 0;
      await pump(tester, AddLivingAvatar(onTap: () => taps++));
      await tester.tap(find.byType(AddLivingAvatar));
      expect(taps, 1);
    });
  });
}
