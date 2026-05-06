import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/actualisation_service.dart';
import 'services/auth_service.dart';
import 'services/backup_service.dart';
import 'services/biometric_service.dart';
import 'services/cave_preferences_service.dart';
import 'services/cave_service.dart';
import 'services/drive_backup_service.dart';
import 'services/gemini_service.dart';
import 'services/govee_service.dart';
import 'services/groq_service.dart';
import 'services/mistral_service.dart';
import 'services/maps_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  // Sur web, finalise la connexion Google après un signInWithRedirect.
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.getRedirectResult();
    } catch (_) {}
  }
  await GeminiService.init();
  await GroqService.init();
  await MistralService.init();
  await MapsService.init();
  await GoveeService.init();
  await CavePreferencesService.init();
  await BackupService.init();
  await DriveBackupService.init();
  await BiometricService.init();
  runApp(const MyApp());

  // Background auto-refresh: ne tourne que si déjà signé en Google
  Future(() async {
    if (!AuthService.isSignedIn) return;
    try {
      final wines = await CaveService.wines().first;
      await ActualisationService.runAutoRefreshIfDue(wines);
    } catch (_) {}
  });

  // Auto-backup quotidien
  Future.delayed(const Duration(seconds: 5), () async {
    if (!AuthService.isSignedIn) return;
    try {
      await BackupService.tryAutoBackup();
    } catch (_) {}
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cave à Vin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9A84C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E0C0A),
        useMaterial3: true,
        fontFamily: 'DMSans',
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'DMSans',
              bodyColor: const Color(0xFFE8E0D0),
              displayColor: const Color(0xFFE8C97A),
            ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Première grille : connexion Google (web + mobile).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        final user = snapshot.data;
        if (user == null || user.isAnonymous) {
          return const _SignInScreen();
        }
        return const _BiometricGate(child: HomeScreen());
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'cancelled' || e.code == 'popup-closed-by-user') {
        setState(() {
          _busy = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _busy = false;
        _error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.wine_bar,
                    color: AppColors.gold, size: 56),
                const SizedBox(height: 18),
                Text(
                  'Cave à Vin',
                  textAlign: TextAlign.center,
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connecte-toi pour accéder à ta cave depuis n\'importe quel appareil.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(color: AppColors.text3, fontSize: 13),
                ),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1A1408),
                          ),
                        )
                      : const Icon(Icons.login, size: 18),
                  label: Text(
                    'Se connecter avec Google',
                    style: AppText.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1A1408),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      color: const Color(0xFFE07060),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Deuxième grille : biométrie (mobile uniquement, optionnelle).
class _BiometricGate extends StatefulWidget {
  final Widget child;
  const _BiometricGate({required this.child});

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybePrompt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (BiometricService.enabled.value && !_unlocked) {
        _maybePrompt();
      }
    } else if (state == AppLifecycleState.paused) {
      if (BiometricService.enabled.value) {
        setState(() => _unlocked = false);
      }
    }
  }

  Future<void> _maybePrompt() async {
    if (!BiometricService.enabled.value) {
      if (!_unlocked && mounted) setState(() => _unlocked = true);
      return;
    }
    if (_prompting) return;
    _prompting = true;
    final ok = await BiometricService.authenticate();
    _prompting = false;
    if (!mounted) return;
    if (ok) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: BiometricService.enabled,
      builder: (context, enabled, _) {
        if (!enabled) return widget.child;
        if (_unlocked) return widget.child;
        return _LockScreen(onUnlock: _maybePrompt);
      },
    );
  }
}

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.gold, size: 56),
            const SizedBox(height: 18),
            Text(
              'Cave verrouillée',
              style: AppText.serif(
                color: AppColors.gold2,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Authentifie-toi pour continuer',
              style: AppText.sans(color: AppColors.text3, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.fingerprint, size: 20),
              label: Text(
                'Déverrouiller',
                style: AppText.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1A1408),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
