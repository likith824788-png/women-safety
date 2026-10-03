import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/resend_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/pin_verification_dialog.dart';

class SettingsProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;

  const SettingsProfileScreen({super.key, this.onBack, this.onNavigate});

  @override
  ConsumerState<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends ConsumerState<SettingsProfileScreen> {
  bool _pushNotificationsEnabled = true;

  Future<void> _toggleGps(bool newValue) async {
    final locationNotifier = ref.read(locationProvider.notifier);
    final locationState = ref.read(locationProvider);
    final contacts = ref.read(contactsProvider);
    final authState = ref.read(authProvider);

    if (!newValue) {
      // User is attempting to turn OFF GPS
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Turn Off GPS Location?'),
          content: const Text(
            'Are you sure you want to turn off GPS location?\n\nYour trusted contacts will be immediately notified of your last known location for your safety.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Keep GPS On'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Turn Off', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Require PIN verification
      if (!mounted) return;
      final pinValid = await PinVerificationDialog.verify(
        context: context,
        actionTitle: 'Turn Off GPS Location',
      );

      if (!pinValid) return;

      // Turn OFF GPS
      locationNotifier.toggleGps(false);

      // Send emergency email notification to contacts
      final emails = contacts
          .where((c) => c.phone.contains('@') || c.email.contains('@'))
          .map((c) => c.email.isNotEmpty ? c.email : c.phone)
          .toList();

      await ResendService.sendSosAlert(
        toEmails: emails.isEmpty
            ? [
                'likith824788@gmail.com',
                'sundreshan21@gmail.com',
                'saibharathchalla29@gmail.com',
                'priyajegan1222@gmail.com',
              ]
            : emails,
        userName: authState.userProfile?.name ?? 'User',
        latitude: locationState.currentLat,
        longitude: locationState.currentLng,
        triggeredBy: 'Manual GPS Location Disable Alert',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ GPS location turned OFF. Last location sent to trusted contacts.'),
            backgroundColor: AppColors.sosRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } else {
      locationNotifier.toggleGps(true);
    }
  }

  Future<void> _togglePushNotifications(bool newValue) async {
    if (!newValue) {
      final pinValid = await PinVerificationDialog.verify(
        context: context,
        actionTitle: 'Disable Push Notifications',
      );
      if (!pinValid) return;
    }
    setState(() => _pushNotificationsEnabled = newValue);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.userProfile;
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: widget.onNavigate != null
          ? AppDrawer(currentIndex: 6, onNavigate: widget.onNavigate!)
          : null,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Open navigation sidebar',
          ),
        ),
        title: const Text('Settings & Profile'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            AppCard(
              backgroundColor: AppColors.primaryNavy,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: profile?.profileImagePath != null &&
                            profile!.profileImagePath!.startsWith('data:')
                        ? NetworkImage(profile.profileImagePath!)
                        : null,
                    child: profile?.profileImagePath == null
                        ? const Icon(Icons.person, size: 40, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Set up your profile',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (profile?.email != null && profile!.email!.isNotEmpty)
                          Text(
                            profile.email!,
                            style: const TextStyle(color: AppColors.textDimmed, fontSize: 13),
                          )
                        else
                          Text(
                            profile?.phone ?? '—',
                            style: const TextStyle(color: AppColors.textDimmed, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Personal Details ───
            const Text('Your Details', style: AppTypography.titleLarge),
            const SizedBox(height: 14),

            _infoRow(Icons.person_outline, 'Full Name', profile?.name ?? '—'),
            _infoRow(Icons.email_outlined, 'Email', profile?.email ?? '—'),
            _infoRow(Icons.phone_outlined, 'Phone Number', profile?.phone ?? '—'),
            _infoRow(Icons.cake_outlined, 'Date of Birth', profile?.dateOfBirth ?? '—'),
            _infoRow(Icons.lock_outline, 'Security PIN', profile?.securityPin != null ? '••••' : '—'),

            const SizedBox(height: 28),

            // ─── App Settings ───
            const Text('App Controls & Safety Settings', style: AppTypography.titleLarge),
            const SizedBox(height: 14),

            _settingToggle(
              icon: Icons.location_on,
              label: 'GPS Location Service',
              subtitle: locationState.isGpsEnabled
                  ? 'Active — precise location monitoring'
                  : 'OFF — requires PIN to disable',
              value: locationState.isGpsEnabled,
              onChanged: _toggleGps,
              iconColor: locationState.isGpsEnabled ? AppColors.safeGreen : AppColors.sosRed,
            ),

            _settingToggle(
              icon: Icons.notifications_active,
              label: 'Push Notifications',
              subtitle: _pushNotificationsEnabled
                  ? 'Active — emergency alerts & route warnings'
                  : 'OFF — requires PIN to disable',
              value: _pushNotificationsEnabled,
              onChanged: _togglePushNotifications,
            ),

            _settingToggle(
              icon: Icons.sms_outlined,
              label: 'SMS Fallback Alerts',
              subtitle: 'Send SMS when internet is unavailable',
              value: true,
              onChanged: (_) {},
            ),

            _settingToggle(
              icon: Icons.battery_alert,
              label: 'Low Battery Protection',
              subtitle: 'Alert guardians when battery < 20%',
              value: true,
              onChanged: (_) {},
            ),

            const SizedBox(height: 28),

            // ─── Sign Out ───
            AppCard(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out?'),
                    content: const Text('You will need to log in again to use Aegis Safety.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out',
                              style: TextStyle(color: AppColors.sosRed))),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).signOut();
                }
              },
              child: const Row(
                children: [
                  Icon(Icons.logout, color: AppColors.sosRed, size: 22),
                  SizedBox(width: 14),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.sosRed,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios, color: AppColors.sosRed, size: 16),
                ],
              ),
            ),

            const SizedBox(height: 12),

            const Center(
              child: Text(
                'Aegis Safety • v1.0.0',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryNavy, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingToggle({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? AppColors.primaryNavy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: effectiveColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primaryNavy,
            ),
          ],
        ),
      ),
    );
  }
}
