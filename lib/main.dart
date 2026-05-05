import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/actualisation_service.dart';
import 'services/cave_preferences_service.dart';
import 'services/cave_service.dart';
import 'services/gemini_service.dart';
import 'services/govee_service.dart';
import 'services/maps_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await GeminiService.init();
  await MapsService.init();
  await GoveeService.init();
  await CavePreferencesService.init();
  runApp(const MyApp());

  // Background auto-refresh: runs silently after app starts, doesn't block UI
  Future(() async {
    try {
      final wines = await CaveService.wines().first;
      await ActualisationService.runAutoRefreshIfDue(wines);
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
      home: const HomeScreen(),
    );
  }
}
