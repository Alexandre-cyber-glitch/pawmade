import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/paw_colors.dart';

// =====================================================================
// Validateurs : mêmes règles que les annotations du back
// (UpdateDogRequest / UpdatePlantRequest) pour éviter les 400.
// =====================================================================

String? validateName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Name is required';
  if (v.length > 50) return 'Max 50 characters';
  return null;
}

/// Vide = OK (null envoyé). Sinon `/chemin` ou `http(s)://…`.
String? validateImageUrl(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (v.contains(' ')) return 'No spaces allowed';
  if (!(v.startsWith('/') ||
      v.startsWith('http://') ||
      v.startsWith('https://'))) {
    return 'Must start with / or http(s)://';
  }
  return null;
}

/// Vide = OK. Sinon > 0, < 1000, 2 décimales max (@Positive @Digits(3,2)).
String? validateWeight(String? value) {
  final v = value?.trim().replaceAll(',', '.') ?? '';
  if (v.isEmpty) return null;
  final w = double.tryParse(v);
  if (w == null) return 'Invalid number';
  if (w <= 0) return 'Must be greater than 0';
  if (w >= 1000) return 'Must be less than 1000';
  final decimals = v.contains('.') ? v.split('.').last.length : 0;
  if (decimals > 2) return 'Max 2 decimals';
  return null;
}

/// Vide = OK. Sinon entier entre 1 et 365 (@Positive @Max(365)).
String? validateWateringDays(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final n = int.tryParse(v);
  if (n == null) return 'Whole number only';
  if (n < 1 || n > 365) return 'Between 1 and 365';
  return null;
}

String? validateSpecies(String? value) =>
    (value?.trim().length ?? 0) > 100 ? 'Max 100 characters' : null;

/// "  " -> null, " /a.jpg " -> "/a.jpg"
String? blankToNull(String value) {
  final v = value.trim();
  return v.isEmpty ? null : v;
}

String formatDisplayDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

// =====================================================================
// Widgets
// =====================================================================

InputDecoration pawInputDecoration(
  String label, {
  String? hint,
  String? helper,
  String? suffixText,
  IconData? icon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    suffixText: suffixText,
    suffixIcon: suffixIcon,
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 20, color: PawColors.caramel),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    labelStyle: TextStyle(color: Colors.grey.shade700),
    floatingLabelStyle: const TextStyle(
      color: PawColors.caramel,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: TextStyle(color: Colors.grey.shade400),
    enabledBorder: border(PawColors.border),
    focusedBorder: border(PawColors.caramel, 1.6),
    errorBorder: border(PawColors.error),
    focusedErrorBorder: border(PawColors.error, 1.6),
    disabledBorder: border(PawColors.border),
  );
}

/// Petit titre de section ("Informations", "Photos"...).
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

/// Champ texte standard du formulaire.
class PawTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? suffixText;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const PawTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.suffixText,
    this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        cursorColor: PawColors.caramel,
        style: const TextStyle(fontSize: 15, color: PawColors.textDark),
        decoration: pawInputDecoration(
          label,
          hint: hint,
          helper: helper,
          suffixText: suffixText,
          icon: icon,
        ),
      ),
    );
  }
}

/// Champ date : ouvre un date picker aux couleurs de l'appli.
class PawDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? helper;
  final bool enabled;

  const PawDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: value != null && !value!.isAfter(today) ? value! : today,
      firstDate: DateTime(1980),
      lastDate: today, // @PastOrPresent côté back
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: PawColors.caramel,
            onPrimary: Colors.white,
            surface: PawColors.cream,
            onSurface: PawColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => _pick(context) : null,
        child: InputDecorator(
          isEmpty: value == null,
          decoration: pawInputDecoration(
            label,
            helper: helper,
            icon: Icons.calendar_today_outlined,
            suffixIcon: value != null && enabled
                ? IconButton(
                    tooltip: 'Clear',
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () => onChanged(null),
                  )
                : null,
          ),
          child: Text(
            value == null ? '' : formatDisplayDate(value!),
            style: const TextStyle(fontSize: 15, color: PawColors.textDark),
          ),
        ),
      ),
    );
  }
}
