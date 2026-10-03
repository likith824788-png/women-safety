import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/user_profile_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _profileImageBase64;
  Uint8List? _profileImageBytes;
  bool _isLoading = false;
  bool _obscurePin = true;
  int _currentStep = 0; // 0 = profile info, 1 = security pin

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64 = base64Encode(bytes);
        setState(() {
          _profileImageBytes = bytes;
          _profileImageBase64 = 'data:image/jpeg;base64,$base64';
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _selectDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
      firstDate: DateTime(1930),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
      return;
    }

    // Step 1 — PIN confirmation
    if (_pinCtrl.text != _confirmPinCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match'),
          backgroundColor: AppColors.sosRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authState = ref.read(authProvider);
    final firebaseUser = FirebaseService.currentUser;
    final profile = UserProfile(
      uid: firebaseUser?.uid ?? authState.userProfile?.uid ?? 'user_local',
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: firebaseUser?.email ?? authState.userProfile?.email,
      dateOfBirth: _dobCtrl.text.trim(),
      securityPin: _pinCtrl.text.trim(),
      profileImagePath: _profileImageBase64,
    );

    await ref.read(authProvider.notifier).saveProfile(profile);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryNavy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text('AEGIS SAFETY',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                          letterSpacing: 1.2,
                        )),
                  ],
                ),
                const SizedBox(height: 30),

                // Step indicator
                Row(
                  children: [
                    _stepDot(0, 'Profile'),
                    Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppColors.primaryNavy : AppColors.borderLight)),
                    _stepDot(1, 'Security'),
                  ],
                ),
                const SizedBox(height: 32),

                if (_currentStep == 0) ...[
                  // === STEP 1: Profile Info ===
                  const Text('Set Up Your Profile', style: AppTypography.headlineMedium),
                  const SizedBox(height: 6),
                  const Text('Your information is stored securely on your device.',
                      style: AppTypography.bodyMedium),
                  const SizedBox(height: 28),

                  // Profile image picker
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: AppColors.primaryNavy,
                            backgroundImage: _profileImageBytes != null
                                ? MemoryImage(_profileImageBytes!)
                                : null,
                            child: _profileImageBytes == null
                                ? const Icon(Icons.person, size: 56, color: Colors.white)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.safeGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Tap to add profile photo',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ),
                  const SizedBox(height: 28),

                  // Name
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _buildField(
                    controller: _phoneCtrl,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 7) ? 'Valid phone required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  TextFormField(
                    controller: _dobCtrl,
                    readOnly: true,
                    onTap: _selectDob,
                    validator: (v) => (v == null || v.isEmpty) ? 'Date of birth is required' : null,
                    decoration: _inputDecoration('Date of Birth', Icons.cake_outlined),
                  ),
                  const SizedBox(height: 30),

                  PrimaryButton(label: 'Continue to Security', onPressed: _submit),
                ] else ...[
                  // === STEP 2: Security PIN ===
                  const Text('Create Security PIN', style: AppTypography.headlineMedium),
                  const SizedBox(height: 6),
                  const Text(
                      'Your 4-digit PIN protects sensitive actions in Aegis Safety.',
                      style: AppTypography.bodyMedium),
                  const SizedBox(height: 28),

                  const Center(
                    child: Icon(Icons.lock_outline, size: 72, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 24),

                  // PIN input
                  TextFormField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: _obscurePin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                    validator: (v) => (v == null || v.length != 4) ? 'PIN must be 4 digits' : null,
                    decoration: _inputDecoration('Enter 4-digit PIN', Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ))
                        .copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 16),

                  // Confirm PIN
                  TextFormField(
                    controller: _confirmPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                    validator: (v) => (v == null || v.length != 4) ? 'Please confirm your PIN' : null,
                    decoration:
                        _inputDecoration('Confirm PIN', Icons.lock_reset_outlined).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 30),

                  PrimaryButton(
                    label: 'Complete Profile',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _currentStep = 0),
                    child: const Text('← Back to Profile Info'),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryNavy : AppColors.surfaceVariant,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? AppColors.primaryNavy : AppColors.borderLight, width: 2),
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.primaryNavy : AppColors.textMuted,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            )),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryNavy),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppColors.textMuted),
    );
  }
}
