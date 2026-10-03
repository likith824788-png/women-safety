import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CountdownRing extends StatelessWidget {
  final int secondsRemaining;
  final int totalSeconds;
  final double size;

  const CountdownRing({
    super.key,
    required this.secondsRemaining,
    required this.totalSeconds,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? (secondsRemaining / totalSeconds) : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: AppColors.sosRedBg,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sosRed),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$secondsRemaining',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppColors.sosRed,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'SECONDS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
