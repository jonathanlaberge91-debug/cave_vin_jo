import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/actualisation_service.dart';
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
  // Auth anonyme : transparent pour l'utilisateur, mais permet de
  // verrouiller les rules Firestore/Storage à `request.auth != null`.
  // L'UID anonyme persiste dans le browser localStorage.
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      // Pas bloquer l'app si auth échoue — les rules feront leur job.
    }
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

  // Background auto-refresh: runs silently after app starts, doesn't block UI
  Future(() async {
    try {
      final wines = await CaveService.wines().first;
      await ActualisationService.runAutoRefreshIfDue(wines);
    } catch (_) {}
  });

  // Auto-backup quotidien : déclenche un download si > 24h depuis le dernier
  Future.delayed(const Duration(seconds: 5), () async {
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
      home: const _AuthGate(child: HomeScreen()),
    );
  }
}

class _AuthGate extends StatefulWidget {
  final Widget child;
  const _AuthGate({required this.child});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
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
