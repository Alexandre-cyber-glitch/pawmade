import 'package:flutter_test/flutter_test.dart';
import 'package:pawmade/features/pets/widgets/edit/edit_form_fields.dart';

/// Les validateurs reprennent les annotations du back
/// (UpdateDogRequest / UpdatePlantRequest) : s'ils laissent passer
/// une valeur, le back ne doit pas répondre 400.
void main() {
  group('validateName (@NotBlank @Size(max = 50))', () {
    test('obligatoire', () {
      expect(validateName(null), isNotNull);
      expect(validateName(''), isNotNull);
      expect(validateName('   '), isNotNull);
    });

    test('50 caractères max (espaces autour ignorés)', () {
      expect(validateName('a' * 50), isNull);
      expect(validateName('a' * 51), isNotNull);
      expect(validateName('  ${'a' * 50}  '), isNull);
    });
  });

  group('validateWeight (@Positive @Digits(3, 2))', () {
    test('vide autorisé', () {
      expect(validateWeight(null), isNull);
      expect(validateWeight(''), isNull);
    });

    test('valeurs valides, virgule acceptée', () {
      expect(validateWeight('12'), isNull);
      expect(validateWeight('12.5'), isNull);
      expect(validateWeight('12,55'), isNull);
      expect(validateWeight('999.99'), isNull);
    });

    test('valeurs refusées', () {
      expect(validateWeight('abc'), 'Invalid number');
      expect(validateWeight('0'), 'Must be greater than 0');
      expect(validateWeight('-1'), 'Must be greater than 0');
      expect(validateWeight('1000'), 'Must be less than 1000');
      expect(validateWeight('1.234'), 'Max 2 decimals');
    });
  });

  group('validateWateringDays (@Positive @Max(365))', () {
    test('bornes', () {
      expect(validateWateringDays(''), isNull);
      expect(validateWateringDays('1'), isNull);
      expect(validateWateringDays('365'), isNull);
      expect(validateWateringDays('0'), 'Between 1 and 365');
      expect(validateWateringDays('366'), 'Between 1 and 365');
    });

    test('entier uniquement', () {
      expect(validateWateringDays('7.5'), 'Whole number only');
      expect(validateWateringDays('sept'), 'Whole number only');
    });
  });

  test('validateSpecies (@Size(max = 100))', () {
    expect(validateSpecies(null), isNull);
    expect(validateSpecies('a' * 100), isNull);
    expect(validateSpecies('a' * 101), 'Max 100 characters');
  });

  test('blankToNull', () {
    expect(blankToNull(''), isNull);
    expect(blankToNull('   '), isNull);
    expect(blankToNull('  Monstera '), 'Monstera');
  });

  test('formatDisplayDate : jj/mm/aaaa', () {
    expect(formatDisplayDate(DateTime(2025, 6, 5)), '05/06/2025');
    expect(formatDisplayDate(DateTime(2025, 12, 31)), '31/12/2025');
  });
}
