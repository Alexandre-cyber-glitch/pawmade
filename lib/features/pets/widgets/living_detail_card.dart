import 'package:flutter/material.dart';

import '../models/living_item.dart';

class LivingDetailCard extends StatelessWidget {
  final LivingItem living;

  const LivingDetailCard({super.key, required this.living});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grande photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              width: double.infinity,
              height: 190,
              child: living.photoUrl != null && living.photoUrl!.isNotEmpty
                  ? Image.network(
                      living.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),

          // Informations
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  living.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _getSubtitle(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),

                const SizedBox(height: 14),

                _buildSpecificInformations(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle() {
    if (living.isDog) {
      return living.breed ?? 'Chien';
    }

    if (living.isPlant) {
      return living.species ?? 'Plante';
    }

    return living.type;
  }

  Widget _buildSpecificInformations() {
    if (living.isDog) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _infoChip(Icons.male, living.sex ?? 'Inconnu'),
          _infoChip(
            Icons.monitor_weight_outlined,
            '${living.weight ?? '-'} kg',
          ),
          _infoChip(
            Icons.cake_outlined,
            living.birthDate == null
                ? 'Date inconnue'
                : '${living.birthDate!.day}/'
                      '${living.birthDate!.month}/'
                      '${living.birthDate!.year}',
          ),
        ],
      );
    }

    if (living.isPlant) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _infoChip(
            Icons.water_drop_outlined,
            'Tous les ${living.wateringFrequencyDays ?? '-'} jours',
          ),
          _infoChip(Icons.eco_outlined, living.species ?? 'Espèce inconnue'),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFB58A62)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF2EDE6),
      child: const Center(
        child: Icon(Icons.photo_outlined, size: 50, color: Color(0xFFB58A62)),
      ),
    );
  }
}
