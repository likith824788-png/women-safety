import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

// Theme
import 'core/theme/app_theme.dart';

// Providers
import 'core/providers/auth_provider.dart';
import 'core/providers/sos_provider.dart';
import 'core/providers/location_provider.dart';

// Auth screens
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/auth/widgets/permission_request_dialog.dart';

// Main pages
import 'features/home/screens/home_screen.dart';
import 'features/location/screens/live_location_screen.dart';
import 'features/companion/screens/companion_setup_screen.dart';
import 'features/ai_checkin/screens/ai_checkin_screen.dart';
import 'features/emergency/screens/nearby_emergency_services_screen.dart';
import 'features/contacts/screens/trusted_contacts_screen.dart';
import 'features/profile/screens/settings_profile_screen.dart';
import 'features/monitor/screens/monitor_screen.dart';

// SOS overlay screens
import 'features/sos/screens/sos_countdown_screen.dart';
import 'features/sos/screens/alert_sent_screen.dart';

// Shared widgets
import 'shared/widgets/app_drawer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: AegisApp()));
}

class AegisApp extends StatelessWidget {
  const AegisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegis Safety',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppRouter(),
    );
  }
}

/// Root router — decides which flow to show based on auth state
class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (!authState.isAuthenticated) {
      // Show onboarding / login screen
      return const OnboardingScreen();
    }

    if (!authState.isProfileComplete) {
      // Show profile setup
      return const ProfileSetupScreen();
    }

    // Authenticated + profile complete → show permission dialog once, then main app
    return const PermissionGateScreen();
  }
}

/// Shows permission dialog on first launch after profile setup, then main app
class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _permissionsDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_permissionsDone) {
      return PermissionRequestDialog(
        onComplete: () {
          setState(() => _permissionsDone = true);
        },
      );
    }
    return const MainNavigationShell();
  }
}

// ─────────────────────────────────────────────────────────────────
//  MAIN NAVIGATION SHELL (Sidebar Drawer)
// ─────────────────────────────────────────────────────────────────

class MainNavigationShell extends ConsumerStatefulWidget {
  final String? initialCompanionLocation;

  const MainNavigationShell({super.key, this.initialCompanionLocation});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;
  String? _pendingCompanionLocation;

  @override
  void initState() {
    super.initState();
    _pendingCompanionLocation = widget.initialCompanionLocation;
  }

  void _navigate(int index) {
    setState(() => _currentIndex = index);
  }

  Widget _buildCurrentPage() {
    final goHome = () => _navigate(0);
    switch (_currentIndex) {
      case 0:
        return HomeScreen(onNavigateTab: _navigate);
      case 1:
        return LiveLocationScreen(onBack: goHome, onNavigate: _navigate);
      case 2:
        return CompanionSetupScreen(
          prefilledDestination: _pendingCompanionLocation,
          onBack: goHome,
          onNavigate: _navigate,
        );
      case 3:
        return AiCheckinScreen(onNavigateTab: _navigate, onBack: goHome);
      case 4:
        return NearbyEmergencyServicesScreen(onBack: goHome, onNavigate: _navigate);
      case 5:
        return TrustedContactsScreen(onBack: goHome, onNavigate: _navigate);
      case 6:
        return SettingsProfileScreen(onBack: goHome, onNavigate: _navigate);
      case 7:
        return MonitorScreen(onBack: goHome, onNavigate: _navigate);
      default:
        return HomeScreen(onNavigateTab: _navigate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);

    // SOS countdown overlay
    if (sosState.isCountdownActive) {
      return const SosCountdownScreen();
    }

    // SOS alert sent screen
    if (sosState.isAlertSent) {
      return const AlertSentScreen();
    }

    return _buildCurrentPage();
  }
}
