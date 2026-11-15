import 'package:flutter/material.dart';

import '../../../core/widgets/safe_network_image.dart';
import '../models/living_detail.dart';

/// Carte "profil" du living sélectionné : grande photo + infos principales.
class LivingDetailCard extends StatelessWidget {
  final LivingDetail living;
  final VoidCallback? onEdit;

  const LivingDetailCard({super.key, required this.living, this.onEdit});

  static const _caramel = Color(0xFFB58A62);
  static const _textDark = Color(0xFF2D2A26);
  static const _radius = 24.0;
  static const _photoHeight = 175.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhoto(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  living.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: _infoChips()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Photo ----------

  Widget _buildPhoto() {
    return SizedBox(
      height: _photoHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover en priorité, sinon l'avatar, sinon le placeholder.
          SafeNetworkImage(
            urls: [living.coverUrl, living.avatarUrl],
            fallback: _placeholder(),
            alignment: Alignment.topCenter,
          ),

          // Léger dégradé en bas pour fondre la photo dans la carte
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x22000000)],
              ),
            ),
          ),

          // Bouton Edit
          Positioned(top: 14, right: 14, child: _editButton()),

          // Petit texte manuscrit
          Positioned(
            right: 20,
            bottom: 26,
            child: Text(
              living.isPlant ? 'My green\nbuddy ♡' : 'My\nBest Friend\n♡',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.15,
                fontStyle: FontStyle.italic,
                color: _textDark,
                shadows: [Shadow(color: Colors.white70, blurRadius: 6)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editButton() {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onEdit,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 16, color: _textDark),
              SizedBox(width: 6),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF2EDE6),
      child: Center(
        child: Icon(
          living.isPlant ? Icons.local_florist : Icons.pets,
          size: 56,
          color: _caramel,
        ),
      ),
    );
  }

  // ---------- Infos ----------

  String get _subtitle {
    if (living.isDog) return living.breedLabel ?? 'Dog';
    if (living.isPlant) return living.species ?? 'Plant';
    return living.typeLabel;
  }

  List<Widget> _infoChips() {
    if (living.isDog) {
      final sex = living.sex;
      return [
        _InfoChip(
          icon: sex == 'FEMALE' ? Icons.female : Icons.male,
          iconColor: sex == 'FEMALE'
              ? const Color(0xFFE07A9B)
              : const Color(0xFF4A8FE2),
          label: living.sexLabel ?? 'Unknown',
        ),
        _InfoChip(
          icon: Icons.calendar_today_outlined,
          label: living.ageLabel ?? '-',
        ),
        _InfoChip(
          icon: Icons.monitor_weight_outlined,
          label: living.weightLabel ?? '- kg',
        ),
      ];
    }

    if (living.isPlant) {
      final acq = living.acquisitionDate;
      return [
        _InfoChip(
          icon: Icons.water_drop_outlined,
          iconColor: const Color(0xFF4A8FE2),
          label: 'Every ${living.wateringFrequencyDays ?? '-'} days',
        ),
        if (acq != null)
          _InfoChip(
            icon: Icons.calendar_today_outlined,
            label:
                '${acq.day.toString().padLeft(2, '0')}/'
                '${acq.month.toString().padLeft(2, '0')}/${acq.year}',
          ),
      ];
    }

    return const [];
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.iconColor = const Color(0xFF2D2A26),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE8DE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2A26),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte "fantôme" affichée pendant le chargement du détail.
class LivingDetailCardSkeleton extends StatelessWidget {
  const LivingDetailCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const shade = Color(0xFFF2EDE6);

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: shade,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 175,
            color: shade,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFB58A62),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(140, 26),
                const SizedBox(height: 8),
                bar(110, 16),
                const SizedBox(height: 16),
                Row(
                  children: [
                    bar(72, 36),
                    const SizedBox(width: 8),
                    bar(72, 36),
                    const SizedBox(width: 8),
                    bar(72, 36),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
