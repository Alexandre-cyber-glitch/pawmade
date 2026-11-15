import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmade/core/api_config.dart';
import 'package:pawmade/core/image_url.dart';
import 'package:pawmade/core/widgets/safe_network_image.dart';
import 'package:pawmade/features/pets/models/living_detail.dart';
import 'package:pawmade/features/pets/models/living_summary.dart';

void main() {
  group('resolveImageUrl', () {
    test('vide / null / espaces -> null', () {
      expect(resolveImageUrl(null), isNull);
      expect(resolveImageUrl(''), isNull);
      expect(resolveImageUrl('   '), isNull);
    });

    test('chemin relatif -> préfixé par baseUrl', () {
      expect(
        resolveImageUrl('/images/avatar/warm-waffle.jpg'),
        '${ApiConfig.baseUrl}/images/avatar/warm-waffle.jpg',
      );
      expect(
        resolveImageUrl('images/cover/warm-waffle.webp'),
        '${ApiConfig.baseUrl}/images/cover/warm-waffle.webp',
      );
    });

    test('URL absolue http(s) -> inchangée', () {
      expect(
        resolveImageUrl('https://images.unsplash.com/photo-1?w=800'),
        'https://images.unsplash.com/photo-1?w=800',
      );
    });

    test('valeurs invalides -> null', () {
      expect(resolveImageUrl("n'importe quoi"), isNull);
      expect(resolveImageUrl('ftp://serveur/img.jpg'), isNull);
      expect(resolveImageUrl('http://'), isNull);
      expect(resolveImageUrl('https://[cassé'), isNull);
      expect(resolveImageUrl('nimp'), isNull);
    });
  });

  group('fromJson tolérant', () {
    test('summary : avatarUrl prioritaire, photoUrl en secours', () {
      final a = LivingSummary.fromJson({
        'id': 1,
        'name': 'Warm Waffle',
        'type': 'DOG',
        'avatarUrl': '/images/avatar/a.jpg',
        'photoUrl': '/old.jpg',
      });
      expect(a.avatarUrl, '/images/avatar/a.jpg');

      final b = LivingSummary.fromJson({
        'id': 1,
        'name': 'Warm Waffle',
        'type': 'DOG',
        'photoUrl': '/old.jpg',
      });
      expect(b.avatarUrl, '/old.jpg');
    });

    test('detail : champs absents ou mauvais type -> pas de crash', () {
      final d = LivingDetail.fromJson({
        'id': 1,
        'name': 'Warm Waffle',
        'type': 'DOG',
        'avatarUrl': 42, // mauvais type
        'coverUrl': null,
        'birthDate': 'pas-une-date',
        'sex': 'MALE',
      });
      expect(d.avatarUrl, isNull);
      expect(d.coverUrl, isNull);
      expect(d.birthDate, isNull);
      expect(d.ageLabel, isNull);
    });
  });

  group('SafeNetworkImage', () {
    testWidgets('URLs vides / invalides -> fallback, aucune exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: SafeNetworkImage(
              urls: [null, '', 'nimp', 'ftp://x'],
              fallback: Text('FALLBACK'),
            ),
          ),
        ),
      );
      expect(find.text('FALLBACK'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('image qui échoue (404) -> fallback, aucune exception', (
      tester,
    ) async {
      // En test, toutes les requêtes HTTP répondent 400 : simule une image KO.
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: SafeNetworkImage(
              urls: ['https://exemple.test/introuvable.jpg'],
              fallback: Text('FALLBACK'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('FALLBACK'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
