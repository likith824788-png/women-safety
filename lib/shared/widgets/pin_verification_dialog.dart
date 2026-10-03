import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'primary_button.dart';

class PinVerificationDialog extends ConsumerStatefulWidget {
  final String actionTitle;

  const PinVerificationDialog({super.key, required this.actionTitle});

  /// Static helper to prompt PIN verification
  static Future<bool> verify({
    required BuildContext context,
    required String actionTitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinVerificationDialog(actionTitle: actionTitle),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends ConsumerState<PinVerificationDialog> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _obscure = true;

  void _verifyPin() {
    final authState = ref.read(authProvider);
    final expectedPin = authState.userProfile?.securityPin ?? '1234';
    final entered = _pinCtrl.text.trim();

    if (entered == expectedPin || (expectedPin.isEmpty && entered.length == 4)) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Incorrect Security PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, color: AppColors.primaryNavy, size: 32),
          ),
          const SizedBox(height: 12),
          const Text(
            'Security Verification',
            style: AppTypography.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your 4-digit Security PIN to verify "${widget.actionTitle}".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _obscure,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                prefixIcon: const Icon(Icons.security, color: AppColors.primaryNavy),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: AppColors.backgroundLight,
              ),
              onSubmitted: (_) => _verifyPin(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.sosRed, fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _verifyPin,
          child: const Text('Verify PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
