import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum StatusPillType { monitoring, alertSent, guardianWatching, safe, warning }

class StatusPill extends StatelessWidget {
  final String label;
  final StatusPillType type;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    this.type = StatusPillType.monitoring,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData defaultIcon;

    switch (type) {
      case StatusPillType.monitoring:
        bg = AppColors.secondaryNavy.withOpacity(0.12);
        fg = AppColors.primaryNavy;
        defaultIcon = Icons.shield_outlined;
        break;
      case StatusPillType.alertSent:
        bg = AppColors.sosRedBg;
        fg = AppColors.sosRed;
        defaultIcon = Icons.error_outline;
        break;
      case StatusPillType.guardianWatching:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        defaultIcon = Icons.visibility_outlined;
        break;
      case StatusPillType.safe:
        bg = AppColors.safeGreenBg;
        fg = AppColors.safeGreen;
        defaultIcon = Icons.check_circle_outline;
        break;
      case StatusPillType.warning:
        bg = AppColors.warningOrangeBg;
        fg = AppColors.warningOrange;
        defaultIcon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
