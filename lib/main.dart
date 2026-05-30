// lib/main.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'core/database/progress_model.dart';
import 'core/providers/firebase_status_provider.dart';
import 'core/providers/isar_provider.dart';
import 'core/services/ad_service.dart';
import 'core/services/play_games_service.dart';
import 'firebase_options.dart';
import 'features/auth/auth_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final dir = await getApplicationDocumentsDirectory();
    final isar = await _openStore(dir.path);

    var firebaseReady = false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      firebaseReady = true;
    } catch (_) {
      // Desktop/debug builds can run without Firebase configuration.
    }

    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // AdMob is only available on supported mobile targets.
    }

    runApp(ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const _App(),
    ));
  }, (error, stack) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(_StartupErrorApp(error: error));
  });
}

Future<Isar> _openStore(String directory) async {
  final schemas = [
    LevelProgressSchema,
    DailyRecordSchema,
    StreakRecordSchema,
    CustomLevelSchema,
    AppSettingsSchema,
    OfflineScoreSchema,
  ];
  try {
    return await Isar.open(
      schemas,
      directory: directory,
      name: 'wrap_maze_store_v3',
    );
  } catch (_) {
    return Isar.open(
      schemas,
      directory: directory,
      name: 'wrap_maze_store_recovery_v1',
    );
  }
}

class _App extends ConsumerStatefulWidget {
  const _App();
  @override
  ConsumerState<_App> createState() => _AppState();
}

class _StartupErrorApp extends StatelessWidget {
  final Object error;

  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 44),
                const SizedBox(height: 16),
                const Text(
                  'Wrap Maze acilamadi',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bu ekrani goruyorsan hata uygulama icinde yakalandi. Mesaji bana gonder, direkt nokta atisi duzelteyim.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  '$error',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppState extends ConsumerState<_App> {
  @override
  void initState() {
    super.initState();
    _postInit();
  }

  Future<void> _postInit() async {
    try {
      await ref.read(playGamesProvider).signIn();
    } catch (_) {}
    try {
      await ref.read(adServiceProvider).initialize();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wrap Maze',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const AuthGate(),
    );
  }

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C3AED), brightness: b),
        scaffoldBackgroundColor: b == Brightness.dark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F8F6),
      );
}
