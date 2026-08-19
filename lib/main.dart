import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_shell.dart';
import 'core/config/auth_service.dart';
import 'features/onboarding/language_screen.dart';
import 'features/onboarding/google_signin_screen.dart';
import 'core/widgets/splash_screen.dart';

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

/// Routes based on a LOCALLY-STORED session read at startup (offline-safe,
/// no network call) — not on the auth stream, which only reacts to
/// FUTURE sign-in/sign-out events during this running session.
/// Splash shows for a fixed duration regardless of how fast auth resolves.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashVisible = true;
  Session? _session;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    // Synchronous, offline-safe: reads the session Supabase already
    // restored from local secure storage during initialize().
    _session = supabase.auth.currentSession;

    // Fixed splash duration, fully decoupled from any auth/network check.
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _splashVisible = false);
    });

    // Reacts to auth changes that happen WHILE the app is open
    // (e.g. sign-in completing). Never blocks the initial routing above.
    _authSub = AuthService.authStateChanges.listen((state) {
      if (mounted) setState(() => _session = state.session);
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_splashVisible) {
      return const SplashScreen();
    }

    if (_session != null) {
      return ResponsiveShell(
        screens: [
          _placeholder('Home'),
          _placeholder('Community'),
          _placeholder('Messages'),
          _placeholder('Marketplace'),
        ],
      );
    }

    return LanguageScreen(
      onContinue: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoogleSignInScreen()),
        );
      },
    );
  }
}

Widget _placeholder(String label) => Center(
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 20)),
    );