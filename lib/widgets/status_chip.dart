import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static StatusChip online(String label) => StatusChip(
        label: label,
        color: AppTheme.accent,
        icon: Icons.wifi_rounded,
      );

  static StatusChip usb(String label) => StatusChip(
        label: label,
        color: AppTheme.warn,
        icon: Icons.usb_rounded,
      );

  static StatusChip offline(String label) => StatusChip(
        label: label,
        color: AppTheme.danger,
        icon: Icons.link_off_rounded,
      );
}
