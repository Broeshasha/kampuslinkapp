import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_shell.dart';
import 'core/widgets/splash_screen.dart';
import 'core/config/auth_service.dart';
import 'features/onboarding/language_screen.dart';
import 'features/onboarding/google_signin_screen.dart';
import 'features/onboarding/profile_setup_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/community/community_screen.dart';
import 'features/marketplace/marketplace_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KampusLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

enum _RouteState { splash, needsAuth, needsProfile, ready }

/// Routing decision, source of truth entirely server-side:
/// - No session -> onboarding.
/// - Session exists -> read profiles.onboarding_complete (a real column,
///   guaranteed to exist the instant auth succeeds via a DB trigger).
/// - Result cached locally, keyed per user ID, for instant offline routing
///   on return visits.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _RouteState _state = _RouteState.splash;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 1800), _resolveRoute);

    _authSub = AuthService.authStateChanges.listen((_) => _resolveRoute());
  }

  Future<void> _resolveRoute() async {
    final session = supabase.auth.currentSession;

    if (session == null) {
      if (mounted) setState(() => _state = _RouteState.needsAuth);
      return;
    }

    final userId = session.user.id;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'onboarding_complete_$userId';

    if (prefs.getBool(cacheKey) == true) {
      if (mounted) setState(() => _state = _RouteState.ready);
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('onboarding_complete')
          .eq('id', userId)
          .single();

      final complete = profile['onboarding_complete'] as bool;

      if (complete) {
        await prefs.setBool(cacheKey, true);
        if (mounted) setState(() => _state = _RouteState.ready);
      } else {
        if (mounted) setState(() => _state = _RouteState.needsProfile);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _RouteState.needsProfile);
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _RouteState.splash:
        return const SplashScreen();

      case _RouteState.needsAuth:
        return LanguageScreen(
          onContinue: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GoogleSignInScreen()),
            );
          },
        );

      case _RouteState.needsProfile:
        return ProfileSetupScreen(
          onComplete: () async {
            final prefs = await SharedPreferences.getInstance();
            final userId = supabase.auth.currentUser!.id;
            await prefs.setBool('onboarding_complete_$userId', true);
            setState(() => _state = _RouteState.ready);
          },
        );

      case _RouteState.ready:
        return ResponsiveShell(
          screens: [
            const HomeScreen(),
            const CommunityScreen(),
            _placeholder('Messages'),
            const MarketplaceScreen(),
          ],
          onAvatarTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        );
    }
  }
}

Widget _placeholder(String label) => Center(
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 20)),
    );