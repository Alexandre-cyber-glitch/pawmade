import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api_exception.dart';
import '../../../../core/theme/paw_colors.dart';
import '../../../../core/widgets/safe_network_image.dart';
import '../../models/living_detail.dart';
import '../../models/living_labels.dart';
import '../../models/living_options.dart';
import '../../models/update_living_request.dart';
import '../../service/living_api.dart';
import 'edit_form_fields.dart';

/// Ouvre le bloc d'édition qui monte du bas.
/// Renvoie le [LivingDetail] à jour si l'utilisateur a enregistré,
/// `null` s'il a fermé sans enregistrer.
Future<LivingDetail?> showEditLivingSheet(
  BuildContext context, {
  required LivingDetail living,
  required LivingApi api,
}) {
  return showModalBottomSheet<LivingDetail>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => EditLivingSheet(living: living, api: api),
  );
}

class EditLivingSheet extends StatefulWidget {
  final LivingDetail living;
  final LivingApi api;

  const EditLivingSheet({super.key, required this.living, required this.api});

  @override
  State<EditLivingSheet> createState() => _EditLivingSheetState();
}

class _EditLivingSheetState extends State<EditLivingSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _weight;
  late final TextEditingController _species;
  late final TextEditingController _watering;
  late final TextEditingController _avatarUrl;
  late final TextEditingController _coverUrl;

  DateTime? _birthDate;
  DateTime? _acquisitionDate;
  String? _sex;
  String? _breed;

  /// URLs affichées dans l'aperçu (mises à jour avec un petit délai
  /// pour ne pas lancer une requête image à chaque lettre tapée).
  String? _previewAvatar;
  String? _previewCover;
  Timer? _previewDebounce;

  bool _saving = false;
  String? _error;

  LivingDetail get _living => widget.living;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _living.name);
    _weight = TextEditingController(text: _formatWeight(_living.weight));
    _species = TextEditingController(text: _living.species ?? '');
    _watering = TextEditingController(
      text: _living.wateringFrequencyDays?.toString() ?? '',
    );
    _avatarUrl = TextEditingController(text: _living.avatarUrl ?? '');
    _coverUrl = TextEditingController(text: _living.coverUrl ?? '');

    _birthDate = _living.birthDate;
    _acquisitionDate = _living.acquisitionDate;
    _sex = _living.sex;
    _breed = _living.breed;

    _previewAvatar = _living.avatarUrl;
    _previewCover = _living.coverUrl;
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    for (final c in [
      _name,
      _weight,
      _species,
      _watering,
      _avatarUrl,
      _coverUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _formatWeight(double? w) {
    if (w == null) return '';
    return w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();
  }

  void _onUrlChanged(String _) {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _previewAvatar = _avatarUrl.text;
        _previewCover = _coverUrl.text;
      });
    });
  }

  UpdateLivingRequest _buildRequest() {
    final name = _name.text.trim();
    final avatar = blankToNull(_avatarUrl.text);
    final cover = blankToNull(_coverUrl.text);

    if (_living.isPlant) {
      return UpdatePlantRequest(
        name: name,
        acquisitionDate: _acquisitionDate,
        species: blankToNull(_species.text),
        wateringFrequencyDays: int.tryParse(_watering.text.trim()),
        avatarUrl: avatar,
        coverUrl: cover,
      );
    }
    return UpdateDogRequest(
      name: name,
      birthDate: _birthDate,
      sex: _sex,
      weight: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
      breed: _breed,
      avatarUrl: avatar,
      coverUrl: cover,
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.api.update(_living.id, _buildRequest());
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: PawColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PhotoPreview(
                        avatarUrl: _previewAvatar,
                        coverUrl: _previewCover,
                        isPlant: _living.isPlant,
                      ),
                      if (_error != null) _ErrorBanner(message: _error!),
                      const SectionLabel('Informations'),
                      PawTextField(
                        controller: _name,
                        label: 'Name',
                        icon: Icons.badge_outlined,
                        validator: validateName,
                        enabled: !_saving,
                      ),
                      ...(_living.isPlant
                          ? _buildPlantFields()
                          : _buildDogFields()),
                      const SectionLabel('Photos'),
                      PawTextField(
                        controller: _avatarUrl,
                        label: 'Avatar URL (circle)',
                        hint: '/avatar/my-pet.jpg',
                        icon: Icons.account_circle_outlined,
                        validator: validateImageUrl,
                        onChanged: _onUrlChanged,
                        keyboardType: TextInputType.url,
                        enabled: !_saving,
                      ),
                      PawTextField(
                        controller: _coverUrl,
                        label: 'Cover URL (card)',
                        hint: '/cover/my-pet.webp',
                        helper: 'Server path (/cover/…) or full http(s) link',
                        icon: Icons.image_outlined,
                        validator: validateImageUrl,
                        onChanged: _onUrlChanged,
                        keyboardType: TextInputType.url,
                        enabled: !_saving,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildSaveBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Edit ${_living.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: PawColors.textDark,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: PawColors.textDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDogFields() {
    final breeds = {...dogBreeds, ?_breed}.toList();

    return [
      PawDateField(
        label: 'Birth date',
        value: _birthDate,
        enabled: !_saving,
        helper: _birthDate == null ? null : ageLabelFor(_birthDate!),
        onChanged: (d) => setState(() => _birthDate = d),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SexSelector(
          value: _sex,
          enabled: !_saving,
          onChanged: (s) => setState(() => _sex = s),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _breed,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Colors.white,
          decoration: pawInputDecoration('Breed', icon: Icons.pets_outlined),
          items: breeds
              .map(
                (b) => DropdownMenuItem(value: b, child: Text(humanizeEnum(b))),
              )
              .toList(),
          onChanged: _saving ? null : (b) => setState(() => _breed = b),
        ),
      ),
      PawTextField(
        controller: _weight,
        label: 'Weight',
        suffixText: 'kg',
        icon: Icons.monitor_weight_outlined,
        validator: validateWeight,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
      ),
    ];
  }

  List<Widget> _buildPlantFields() {
    return [
      PawTextField(
        controller: _species,
        label: 'Species',
        icon: Icons.eco_outlined,
        validator: validateSpecies,
        enabled: !_saving,
      ),
      PawDateField(
        label: 'Acquisition date',
        value: _acquisitionDate,
        enabled: !_saving,
        onChanged: (d) => setState(() => _acquisitionDate = d),
      ),
      PawTextField(
        controller: _watering,
        label: 'Watering every',
        suffixText: 'days',
        icon: Icons.water_drop_outlined,
        validator: validateWateringDays,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    ];
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: PawColors.cream,
        border: Border(top: BorderSide(color: PawColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: PawColors.caramel,
              disabledBackgroundColor: PawColors.caramel.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Aperçu en direct : cover en fond + avatar rond par-dessus.
class _PhotoPreview extends StatelessWidget {
  final String? avatarUrl;
  final String? coverUrl;
  final bool isPlant;

  const _PhotoPreview({
    required this.avatarUrl,
    required this.coverUrl,
    required this.isPlant,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isPlant ? Icons.local_florist : Icons.pets;

    Widget placeholder(double size) => Container(
      color: PawColors.sand,
      alignment: Alignment.center,
      child: Icon(icon, size: size, color: PawColors.caramel),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: SafeNetworkImage(
                urls: [coverUrl],
                fallback: placeholder(40),
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: -28,
            child: Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: PawColors.caramel, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: SafeNetworkImage(
                  urls: [avatarUrl],
                  fallback: placeholder(26),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PawColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Male / Female, aux couleurs des puces de la carte.
class _SexSelector extends StatelessWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _SexSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(String sex, IconData icon, Color color) {
      final selected = value == sex;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // Re-cliquer sur le choix actuel le désélectionne (sexe inconnu).
          onTap: enabled ? () => onChanged(selected ? null : sex) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : PawColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Text(
                  humanizeEnum(sex),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: PawColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(sexes[0], Icons.male, PawColors.male),
        const SizedBox(width: 10),
        option(sexes[1], Icons.female, PawColors.female),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PawColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PawColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: PawColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: PawColors.error, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
