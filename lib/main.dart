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

/// Listens to Supabase auth state and routes automatically —
/// signed out -> onboarding, signed in -> the real app.
/// Shows the splash screen while the session is still resolving,
/// including during the web OAuth redirect bounce-back.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final session = supabase.auth.currentSession;

        if (session != null) {
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
      },
    );
  }
}

Widget _placeholder(String label) => Center(
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 20)),
    );