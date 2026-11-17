import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api_exception.dart';
import '../../../../core/theme/paw_colors.dart';
import '../../../../core/widgets/safe_network_image.dart';
import '../../models/living_detail.dart';
import '../../models/living_labels.dart';
import '../../models/living_options.dart';
import '../../models/photo_upload.dart';
import '../../models/update_living_request.dart';
import '../../service/living_api.dart';
import 'edit_form_fields.dart';

/// Ouvre un sélecteur d'image et renvoie le fichier choisi
/// (`null` si l'utilisateur annule). Remplaçable dans les tests.
typedef PickImage = Future<XFile?> Function();

/// Galerie du téléphone (ou sélecteur de fichier sur web / desktop).
/// Redimensionnée et compressée avant l'envoi : une photo de téléphone
/// fait souvent 5-10 Mo, inutile pour un avatar ou une carte.
/// La compression convertit aussi le HEIC des iPhone en JPEG
/// (le back n'accepte que JPEG / PNG / WEBP).
Future<XFile?> pickFromGallery() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 2048,
  maxHeight: 2048,
  imageQuality: 85,
);

/// Ouvre le bloc d'édition qui monte du bas.
/// Renvoie le [LivingDetail] à jour si l'utilisateur a enregistré,
/// `null` s'il a fermé sans enregistrer.
///
/// Un changement de photo est enregistré tout de suite côté back
/// (indépendamment du bouton Save) : [onPhotoChanged] est alors appelé
/// avec le détail à jour pour rafraîchir la carte et le cercle.
Future<LivingDetail?> showEditLivingSheet(
  BuildContext context, {
  required LivingDetail living,
  required LivingApi api,
  ValueChanged<LivingDetail>? onPhotoChanged,
  PickImage pickImage = pickFromGallery,
}) {
  return showModalBottomSheet<LivingDetail>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => EditLivingSheet(
      living: living,
      api: api,
      onPhotoChanged: onPhotoChanged,
      pickImage: pickImage,
    ),
  );
}

class EditLivingSheet extends StatefulWidget {
  final LivingDetail living;
  final LivingApi api;
  final ValueChanged<LivingDetail>? onPhotoChanged;
  final PickImage pickImage;

  const EditLivingSheet({
    super.key,
    required this.living,
    required this.api,
    this.onPhotoChanged,
    this.pickImage = pickFromGallery,
  });

  @override
  State<EditLivingSheet> createState() => _EditLivingSheetState();
}

class _EditLivingSheetState extends State<EditLivingSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _weight;
  late final TextEditingController _species;
  late final TextEditingController _watering;

  DateTime? _birthDate;
  DateTime? _acquisitionDate;
  String? _sex;
  String? _breed;

  /// Photos affichées en haut du bloc (changent après un upload).
  String? _avatarUrl;
  String? _coverUrl;

  /// Photo en cours d'envoi (pour afficher le loader au bon endroit).
  PhotoSlot? _uploading;

  bool _saving = false;
  String? _error;

  LivingDetail get _living => widget.living;

  /// Pendant un envoi (formulaire ou photo), on bloque les autres actions.
  bool get _busy => _saving || _uploading != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _living.name);
    _weight = TextEditingController(text: _formatWeight(_living.weight));
    _species = TextEditingController(text: _living.species ?? '');
    _watering = TextEditingController(
      text: _living.wateringFrequencyDays?.toString() ?? '',
    );

    _birthDate = _living.birthDate;
    _acquisitionDate = _living.acquisitionDate;
    _sex = _living.sex;
    _breed = _living.breed;
    _avatarUrl = _living.avatarUrl;
    _coverUrl = _living.coverUrl;
  }

  @override
  void dispose() {
    for (final c in [_name, _weight, _species, _watering]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _formatWeight(double? w) {
    if (w == null) return '';
    return w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();
  }

  UpdateLivingRequest _buildRequest() {
    final name = _name.text.trim();

    if (_living.isPlant) {
      return UpdatePlantRequest(
        name: name,
        acquisitionDate: _acquisitionDate,
        species: blankToNull(_species.text),
        wateringFrequencyDays: int.tryParse(_watering.text.trim()),
      );
    }
    return UpdateDogRequest(
      name: name,
      birthDate: _birthDate,
      sex: _sex,
      weight: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
      breed: _breed,
    );
  }

  /// Galerie -> upload -> set avatar/cover, en une action.
  Future<void> _changePhoto(PhotoSlot slot) async {
    if (_busy) return;
    setState(() => _error = null);

    final XFile? file;
    try {
      file = await widget.pickImage();
    } catch (e) {
      debugPrint('Image picker KO : $e');
      if (mounted) setState(() => _error = 'Cannot open the gallery.');
      return;
    }
    if (file == null || !mounted) return; // annulé

    setState(() => _uploading = slot);
    try {
      final bytes = await file.readAsBytes();
      final updated = await widget.api.changePhoto(
        _living.id,
        slot,
        bytes: bytes,
        // Le back détecte le vrai format depuis les octets ;
        // le nom sert juste à avoir une part multipart "fichier".
        filename: file.name.isNotEmpty ? file.name : 'photo.jpg',
      );
      // Prévenir l'écran même si le bloc a été fermé entre-temps :
      // la photo est déjà enregistrée côté back.
      widget.onPhotoChanged?.call(updated);
      if (!mounted) return;
      setState(() {
        _uploading = null;
        _avatarUrl = updated.avatarUrl;
        _coverUrl = updated.coverUrl;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = null;
        _error = e.message;
      });
    }
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
                      // Photos actuelles + boutons pour les changer
                      // (enregistré tout de suite, sans attendre Save).
                      _PhotoPreview(
                        avatarUrl: _avatarUrl,
                        coverUrl: _coverUrl,
                        isPlant: _living.isPlant,
                        uploading: _uploading,
                        onChange: _busy ? null : _changePhoto,
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
            onPressed: _busy ? null : _save,
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

/// Photos actuelles : cover en fond + avatar rond par-dessus,
/// chacune avec un bouton pour la changer depuis la galerie.
class _PhotoPreview extends StatelessWidget {
  final String? avatarUrl;
  final String? coverUrl;
  final bool isPlant;

  /// Photo en cours d'envoi (loader affiché dessus).
  final PhotoSlot? uploading;

  /// `null` = boutons désactivés (envoi en cours).
  final ValueChanged<PhotoSlot>? onChange;

  const _PhotoPreview({
    required this.avatarUrl,
    required this.coverUrl,
    required this.isPlant,
    required this.uploading,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isPlant ? Icons.local_florist : Icons.pets;

    Widget placeholder(double size) => Container(
      color: PawColors.sand,
      alignment: Alignment.center,
      child: Icon(icon, size: size, color: PawColors.caramel),
    );

    // Voile + loader pendant l'envoi.
    Widget loaderOverlay() => Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ---------- Cover ----------
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(
                    key: ValueKey(coverUrl),
                    urls: [coverUrl],
                    fallback: placeholder(40),
                    alignment: Alignment.topCenter,
                  ),
                  if (uploading == PhotoSlot.cover) loaderOverlay(),
                ],
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: _ChangePhotoPill(
              label: 'Change cover',
              onTap: onChange == null ? null : () => onChange!(PhotoSlot.cover),
            ),
          ),

          // ---------- Avatar ----------
          Positioned(
            left: 16,
            bottom: -28,
            child: Tooltip(
              message: 'Change avatar',
              child: GestureDetector(
                onTap: onChange == null
                    ? null
                    : () => onChange!(PhotoSlot.avatar),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: PawColors.caramel,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SafeNetworkImage(
                              key: ValueKey(avatarUrl),
                              urls: [avatarUrl],
                              fallback: placeholder(26),
                            ),
                            if (uploading == PhotoSlot.avatar) loaderOverlay(),
                          ],
                        ),
                      ),
                    ),
                    // Petite pastille appareil photo.
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: onChange == null
                              ? PawColors.caramel.withValues(alpha: 0.6)
                              : PawColors.caramel,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_camera,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton blanc arrondi posé sur la cover.
class _ChangePhotoPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ChangePhotoPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? 0.6 : 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: 15,
                color: PawColors.textDark,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PawColors.textDark,
                ),
              ),
            ],
          ),
        ),
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
