import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';

class PermissionRequestDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const PermissionRequestDialog({super.key, required this.onComplete});

  @override
  State<PermissionRequestDialog> createState() => _PermissionRequestDialogState();
}

class _PermissionRequestDialogState extends State<PermissionRequestDialog> {
  int _step = 0; // 0 = GPS, 1 = Notifications
  bool _isRequesting = false;

  Future<void> _requestGps() async {
    setState(() => _isRequesting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    // On web, browser will show native permission dialog
    setState(() {
      _isRequesting = false;
      _step = 1;
    });
  }

  Future<void> _requestNotifications() async {
    setState(() => _isRequesting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _isRequesting = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isGpsStep = _step == 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(0, isGpsStep),
                    const SizedBox(width: 8),
                    Container(width: 40, height: 3, color: _step >= 1 ? AppColors.primaryNavy : AppColors.borderLight),
                    const SizedBox(width: 8),
                    _dot(1, !isGpsStep),
                  ],
                ),
                const SizedBox(height: 28),

                // Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isGpsStep
                        ? const Color(0xFFE0F2FE)
                        : AppColors.primaryNavy.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGpsStep ? Icons.location_on : Icons.notifications_active,
                    color: isGpsStep ? const Color(0xFF0284C7) : AppColors.primaryNavy,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 22),

                // Title
                Text(
                  isGpsStep ? 'Enable GPS Location' : 'Enable Push Notifications',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  isGpsStep
                      ? 'Aegis Safety needs your location to send precise emergency alerts and enable companion mode route monitoring.'
                      : 'Allow notifications to receive safety alerts from guardians, SOS confirmations, and route deviation warnings.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Required label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.sosRed.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '⚠️ Required for your safety — cannot be skipped',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.sosRed,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),

                PrimaryButton(
                  label: isGpsStep ? 'Enable GPS Location' : 'Enable Notifications',
                  icon: isGpsStep ? Icons.location_on : Icons.notifications,
                  isLoading: _isRequesting,
                  onPressed: isGpsStep ? _requestGps : _requestNotifications,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(int index, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 14 : 10,
      height: isActive ? 14 : 10,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryNavy : AppColors.borderLight,
        shape: BoxShape.circle,
      ),
    );
  }
}
