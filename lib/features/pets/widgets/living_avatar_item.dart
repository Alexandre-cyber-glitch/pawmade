import 'package:flutter/material.dart';

import '../models/living_item.dart';
import 'dotted_circle.dart';

class LivingAvatarItem extends StatelessWidget {
  final LivingItem living;
  final bool isSelected;
  final VoidCallback onTap;

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

    final avatar = ClipOval(
      child: living.photoUrl != null && living.photoUrl!.isNotEmpty
          ? Image.network(
              living.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(fallbackIcon, size: 40);
              },
            )
          : Icon(fallbackIcon, size: 30),
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: isSelected
                  ? Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: caramel, width: 2),
                      ),
                      child: avatar,
                    )
                  : DottedCircle(
                      size: 68,
                      color: caramel,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: avatar,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              living.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              living.type,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
