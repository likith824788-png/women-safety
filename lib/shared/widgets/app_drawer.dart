import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';

class AppDrawer extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;

  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  // Navigation item index mapping:
  // 0 = Home, 1 = Live Share, 2 = Companion, 3 = AI Check-in,
  // 4 = Nearby Services, 5 = Trusted Contacts, 6 = Settings

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.userProfile;

    return Drawer(
      backgroundColor: AppColors.primaryNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.secondaryNavy,
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Profile avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  backgroundImage: profile?.profileImagePath != null &&
                          profile!.profileImagePath!.startsWith('data:')
                      ? NetworkImage(profile.profileImagePath!)
                      : null,
                  child: profile?.profileImagePath == null
                      ? const Icon(Icons.person, size: 34, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.name ?? 'Aegis User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile?.phone ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildNavItem(context, index: 0, icon: Icons.shield, label: 'Home'),
                _buildNavItem(context, index: 1, icon: Icons.share_location, label: 'Live Location Share'),
                _buildNavItem(context, index: 2, icon: Icons.navigation, label: 'Companion Mode'),
                _buildNavItem(context, index: 3, icon: Icons.psychology, label: 'AI Safety Check-in'),
                _buildNavItem(context, index: 4, icon: Icons.local_police, label: 'Nearby Services'),
                _buildNavItem(context, index: 7, icon: Icons.monitor_heart, label: 'Monitor'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                _buildNavItem(context, index: 5, icon: Icons.people, label: 'Trusted Contacts'),
                _buildNavItem(context, index: 6, icon: Icons.settings, label: 'Settings & Profile'),
              ],
            ),
          ),


          // Sign out
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.sosRed),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).signOut();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white60,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        trailing: isActive
            ? Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.safeGreen,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context); // Close drawer
          onNavigate(index);
        },
      ),
    );
  }
}
