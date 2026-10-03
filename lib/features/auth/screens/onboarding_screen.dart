import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';

enum _AuthMode { signIn, signUp }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _resetEmailCtrl = TextEditingController();

  int _currentPage = 0;
  bool _showAuthForm = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  _AuthMode _authMode = _AuthMode.signIn;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Instant Emergency Protection',
      'subtitle':
          'Trigger rapid multi-channel SOS alerts to trusted contacts and police with a single long-press.',
      'icon': Icons.shield,
      'color': AppColors.sosRed,
    },
    {
      'title': 'AI Safety Check-in',
      'subtitle':
          'On-device ambient audio and NLP threat detection keep watch during late walks or risky trips.',
      'icon': Icons.psychology,
      'color': AppColors.primaryNavy,
    },
    {
      'title': 'Companion Tracking',
      'subtitle':
          'Share live routes with guardians. Automatic route deviation and ETA expiry alerts protect your journey.',
      'icon': Icons.navigation,
      'color': AppColors.safeGreen,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _resetEmailCtrl.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    _resetEmailCtrl.text = _emailCtrl.text;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppColors.primaryNavy),
            SizedBox(width: 10),
            Text('Reset Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a password reset link.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(authProvider.notifier)
                  .sendPasswordReset(_resetEmailCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('✉️ Password reset email sent! Check your inbox.'),
                    backgroundColor: AppColors.safeGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password.'),
          backgroundColor: AppColors.sosRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_authMode == _AuthMode.signUp) {
      if (password != _confirmPasswordCtrl.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: AppColors.sosRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
            backgroundColor: AppColors.sosRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await ref
          .read(authProvider.notifier)
          .signUpWithEmail(email: email, password: password);
    } else {
      await ref
          .read(authProvider.notifier)
          .signInWithEmail(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              // ── Header Logo ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryNavy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AEGIS SAFETY',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Feature Carousel ─────────────────────────────────────────
              if (!_showAuthForm) ...[
                SizedBox(
                  height: 260,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _slides.length,
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: (slide['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              slide['icon'] as IconData,
                              size: 60,
                              color: slide['color'] as Color,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            slide['title']!,
                            style: AppTypography.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            slide['subtitle']!,
                            style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Page indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? AppColors.primaryNavy
                            : AppColors.primaryNavy.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Get Started button
                PrimaryButton(
                  label: 'Get Started',
                  isLoading: false,
                  onPressed: () => setState(() => _showAuthForm = true),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAuthForm = true;
                      _authMode = _AuthMode.signIn;
                    });
                  },
                  child: const Text(
                    'Already have an account? Sign In',
                    style: TextStyle(color: AppColors.primaryNavy),
                  ),
                ),

              ] else ...[
                // ── Auth Form ────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mode toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              _ModeTab(
                                label: 'Sign In',
                                selected: _authMode == _AuthMode.signIn,
                                onTap: () =>
                                    setState(() => _authMode = _AuthMode.signIn),
                              ),
                              _ModeTab(
                                label: 'Create Account',
                                selected: _authMode == _AuthMode.signUp,
                                onTap: () =>
                                    setState(() => _authMode = _AuthMode.signUp),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          _authMode == _AuthMode.signIn
                              ? 'Welcome back!'
                              : 'Create your account',
                          style: AppTypography.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _authMode == _AuthMode.signIn
                              ? 'Sign in to access your safety dashboard.'
                              : 'Join Aegis Safety to stay protected.',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 22),

                        // Email field
                        _InputField(
                          controller: _emailCtrl,
                          label: 'Email Address',
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),

                        // Password field
                        _InputField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),

                        if (_authMode == _AuthMode.signUp) ...[
                          const SizedBox(height: 14),
                          _InputField(
                            controller: _confirmPasswordCtrl,
                            label: 'Confirm Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirm,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ],

                        if (_authMode == _AuthMode.signIn)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primaryNavy,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 14),

                        // Error banner
                        if (authState.error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.sosRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.sosRed.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.sosRed, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.error!,
                                    style: const TextStyle(
                                      color: AppColors.sosRed,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Email Auth Button
                        PrimaryButton(
                          label: _authMode == _AuthMode.signIn
                              ? 'Sign In'
                              : 'Create Account',
                          isLoading: authState.isLoading,
                          onPressed: _handleEmailAuth,
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            const Expanded(
                                child: Divider(color: AppColors.borderLight)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: AppColors.borderLight)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Google Sign In Button
                        _GoogleSignInButton(
                          isLoading: authState.isLoading,
                          onPressed: () =>
                              ref.read(authProvider.notifier).signInWithGoogle(),
                        ),
                        const SizedBox(height: 14),

                        // Back to slides
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _showAuthForm = false),
                            child: const Text(
                              '← Back',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mode Toggle Tab ──────────────────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryNavy, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── Google Sign In Button ────────────────────────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton(
      {required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.borderLight, width: 1.5),
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google G logo in coloured letters
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                            text: 'G',
                            style: TextStyle(color: Color(0xFF4285F4))),
                        TextSpan(
                            text: 'o',
                            style: TextStyle(color: Color(0xFFDB4437))),
                        TextSpan(
                            text: 'o',
                            style: TextStyle(color: Color(0xFFF4B400))),
                        TextSpan(
                            text: 'g',
                            style: TextStyle(color: Color(0xFF4285F4))),
                        TextSpan(
                            text: 'l',
                            style: TextStyle(color: Color(0xFF0F9D58))),
                        TextSpan(
                            text: 'e',
                            style: TextStyle(color: Color(0xFFDB4437))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
