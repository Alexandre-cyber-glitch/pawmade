import 'package:flutter_test/flutter_test.dart';
import 'package:pawmade/features/pets/models/living_detail.dart';
import 'package:pawmade/features/pets/models/living_labels.dart';
import 'package:pawmade/features/pets/models/living_summary.dart';
import 'package:pawmade/features/pets/models/photo_upload.dart';
import 'package:pawmade/features/pets/models/update_living_request.dart';

void main() {
  group('humanizeEnum', () {
    test('enum du back -> libellé lisible', () {
      expect(humanizeEnum('GOLDEN_RETRIEVER'), 'Golden Retriever');
      expect(humanizeEnum('GERMAN_SHEPHERD'), 'German Shepherd');
      expect(humanizeEnum('DOG'), 'Dog');
      expect(humanizeEnum('MALE'), 'Male');
    });

    test('cas limites : vide, underscores en trop', () {
      expect(humanizeEnum(''), '');
      expect(humanizeEnum('A__B_'), 'A B');
    });
  });

  group('readString', () {
    test('renvoie la valeur seulement si c\'est une String', () {
      final json = <String, dynamic>{'s': 'ok', 'n': 42, 'nul': null};
      expect(readString(json, 's'), 'ok');
      expect(readString(json, 'n'), isNull);
      expect(readString(json, 'nul'), isNull);
      expect(readString(json, 'absent'), isNull);
    });
  });

  group('ageLabelFor', () {
    final birth = DateTime(2025, 6, 15);

    test('moins d\'un an -> mois', () {
      expect(ageLabelFor(birth, now: DateTime(2025, 6, 20)), '0 Months');
      expect(ageLabelFor(birth, now: DateTime(2025, 7, 15)), '1 Month');
      expect(ageLabelFor(birth, now: DateTime(2025, 11, 20)), '5 Months');
    });

    test('le jour du mois compte (pas encore le mois complet)', () {
      expect(ageLabelFor(birth, now: DateTime(2025, 11, 14)), '4 Months');
      expect(ageLabelFor(birth, now: DateTime(2026, 6, 14)), '11 Months');
    });

    test('un an et plus -> années', () {
      expect(ageLabelFor(birth, now: DateTime(2026, 6, 15)), '1 Year');
      expect(ageLabelFor(birth, now: DateTime(2028, 6, 15)), '3 Years');
      expect(ageLabelFor(birth, now: DateTime(2028, 6, 14)), '2 Years');
    });

    test('date dans le futur -> 0, jamais négatif', () {
      expect(ageLabelFor(birth, now: DateTime(2025, 1, 1)), '0 Months');
    });
  });

  group('anniversaire', () {
    final birth = DateTime(2025, 6, 15);
    String? label(int y, int m, int d, {DateTime? from}) =>
        birthdayLabelFor(from ?? birth, now: DateTime(y, m, d, 23, 30));

    test('libellé selon le nombre de jours restants', () {
      expect(label(2026, 6, 15), 'Birthday today!');
      expect(label(2026, 6, 14), 'Birthday tomorrow');
      expect(label(2026, 6, 3), 'Birthday in 12 days');
    });

    test('affiché à 30 jours, masqué à 31 et juste après', () {
      expect(label(2026, 5, 16), 'Birthday in 30 days');
      expect(label(2026, 5, 15), isNull);
      expect(label(2026, 6, 16), isNull);
    });

    test("passage à l'année suivante", () {
      expect(
        label(2026, 12, 30, from: DateTime(2024, 1, 2)),
        'Birthday in 3 days',
      );
    });

    test("changement d'heure : pas de jour perdu", () {
      expect(
        label(2026, 3, 28, from: DateTime(2024, 3, 30)),
        'Birthday in 2 days',
      );
    });

    test('né un 29 février', () {
      final leap = DateTime(2024, 2, 29);
      expect(label(2026, 3, 1, from: leap), 'Birthday today!');
      expect(label(2028, 2, 29, from: leap), 'Birthday today!');
    });

    test("naissance aujourd'hui ou future : rien", () {
      expect(label(2025, 6, 15), isNull);
      expect(label(2025, 6, 1), isNull);
    });
  });

  group('LivingSummary', () {
    test('fromJson avec la réponse réelle du back', () {
      final s = LivingSummary.fromJson({
        'id': 1,
        'name': 'Warm Waffle',
        'avatarUrl': '/api/photos/00000000-0000-0000-0000-000000000001/content',
        'type': 'DOG',
      });
      expect(s.id, 1);
      expect(s.name, 'Warm Waffle');
      expect(s.avatarUrl, contains('/api/photos/'));
      expect(s.isPlant, isFalse);
      expect(s.typeLabel, 'Dog');
    });

    test('champs manquants -> valeurs par défaut, pas de crash', () {
      final s = LivingSummary.fromJson({'id': 2});
      expect(s.name, '');
      expect(s.type, '');
      expect(s.avatarUrl, isNull);
    });

    test('plante', () {
      final s = LivingSummary.fromJson({'id': 2, 'name': 'A', 'type': 'PLANT'});
      expect(s.isPlant, isTrue);
      expect(s.typeLabel, 'Plant');
    });
  });

  group('LivingDetail', () {
    test('fromJson chien (réponse réelle du back)', () {
      final d = LivingDetail.fromJson({
        'id': 1,
        'name': 'Warm Waffle',
        'coverUrl': '/api/photos/2/content',
        'avatarUrl': '/api/photos/1/content',
        'type': 'DOG',
        'birthDate': '2025-06-15',
        'sex': 'MALE',
        'weight': 12.50,
        'breed': 'GOLDEN_RETRIEVER',
      });
      expect(d.isDog, isTrue);
      expect(d.isPlant, isFalse);
      expect(d.birthDate, DateTime(2025, 6, 15));
      expect(d.weight, 12.5);
      expect(d.avatarUrl, '/api/photos/1/content');
      expect(d.coverUrl, '/api/photos/2/content');
      expect(d.typeLabel, 'Dog');
      expect(d.breedLabel, 'Golden Retriever');
      expect(d.sexLabel, 'Male');
      expect(d.ageLabel, isNotNull);
    });

    test('fromJson plante', () {
      final d = LivingDetail.fromJson({
        'id': 2,
        'name': 'Albert',
        'type': 'PLANT',
        'species': 'Monstera Deliciosa',
        'acquisitionDate': '2025-08-10',
        'wateringFrequencyDays': 7,
      });
      expect(d.isPlant, isTrue);
      expect(d.species, 'Monstera Deliciosa');
      expect(d.acquisitionDate, DateTime(2025, 8, 10));
      expect(d.wateringFrequencyDays, 7);
      expect(d.breedLabel, isNull);
      expect(d.weightLabel, isNull);
    });

    test('poids entier envoyé comme int par le back', () {
      final d = LivingDetail.fromJson({'id': 1, 'type': 'DOG', 'weight': 28});
      expect(d.weight, 28.0);
    });

    test('weightLabel : pas de ".0" inutile', () {
      LivingDetail withWeight(double? w) =>
          LivingDetail(id: 1, name: 'x', type: 'DOG', weight: w);
      expect(withWeight(12.5).weightLabel, '12.5 kg');
      expect(withWeight(28).weightLabel, '28 kg');
      expect(withWeight(null).weightLabel, isNull);
    });

    test('labels null quand la donnée manque', () {
      const d = LivingDetail(id: 1, name: 'x', type: 'DOG');
      expect(d.breedLabel, isNull);
      expect(d.sexLabel, isNull);
      expect(d.ageLabel, isNull);
    });
  });

  group('PhotoUpload / PhotoSlot', () {
    test('fromJson avec la réponse de l\'upload', () {
      final p = PhotoUpload.fromJson({
        'id': 'abc-123',
        'url': '/api/photos/abc-123/content',
        'contentType': 'image/jpeg',
        'sizeBytes': 67752,
      });
      expect(p.id, 'abc-123');
      expect(p.url, '/api/photos/abc-123/content');
    });

    test('url absente ou mauvais type -> null', () {
      expect(PhotoUpload.fromJson({'id': 'a'}).url, isNull);
      expect(PhotoUpload.fromJson({'id': 'a', 'url': 3}).url, isNull);
    });

    test('segment d\'URL de chaque emplacement', () {
      expect(PhotoSlot.avatar.path, 'avatar');
      expect(PhotoSlot.cover.path, 'cover');
    });
  });

  group('requêtes de mise à jour', () {
    test('formatApiDate : format LocalDate yyyy-MM-dd', () {
      expect(formatApiDate(DateTime(2025, 6, 5)), '2025-06-05');
      expect(formatApiDate(DateTime(2025, 12, 31)), '2025-12-31');
      expect(formatApiDate(null), isNull);
    });

    test('chien : toutes les clés présentes, null explicite (PUT complet)', () {
      final json = const UpdateDogRequest(name: 'Buddy').toJson();
      expect(json, {
        'type': 'DOG',
        'name': 'Buddy',
        'birthDate': null,
        'sex': null,
        'weight': null,
        'breed': null,
      });
    });

    test('plante : format attendu par le back', () {
      final json = UpdatePlantRequest(
        name: 'Albert',
        acquisitionDate: DateTime(2025, 8, 10),
        species: 'Monstera',
        wateringFrequencyDays: 7,
      ).toJson();
      expect(json, {
        'type': 'PLANT',
        'name': 'Albert',
        'acquisitionDate': '2025-08-10',
        'species': 'Monstera',
        'wateringFrequencyDays': 7,
      });
    });
  });
}
