import 'package:flutter/material.dart';

import '../../../core/widgets/safe_network_image.dart';
import '../models/living_summary.dart';

class LivingAvatarItem extends StatelessWidget {
  final LivingSummary living;
  final bool isSelected;
  final VoidCallback onTap;

  static const double size = 88;

  const LivingAvatarItem({
    super.key,
    required this.living,
    required this.isSelected,
    required this.onTap,
  });

  IconData get fallbackIcon {
    switch (living.type) {
      case 'PLANT':
        return Icons.local_florist;
      default:
        return Icons.pets;
    }
  }

  @override
  Widget build(BuildContext context) {
    const caramel = Color(0xFFB58A62);
    const textDark = Color(0xFF2D2A26);

    final fallback = Container(
      color: const Color(0xFFF2EDE6),
      child: Icon(fallbackIcon, size: 30, color: caramel),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size + 8,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              padding: EdgeInsets.all(isSelected ? 3 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isSelected ? caramel : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: SizedBox.expand(
                  child: SafeNetworkImage(
                    urls: [living.avatarUrl],
                    fallback: fallback,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              living.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              living.typeLabel,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton "Add Pet" rond de la liste horizontale.
class AddLivingAvatar extends StatelessWidget {
  final VoidCallback? onTap;

  const AddLivingAvatar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: LivingAvatarItem.size + 8,
        child: Column(
          children: [
            Container(
              width: LivingAvatarItem.size,
              height: LivingAvatarItem.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.add, size: 30, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add Pet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2A26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
