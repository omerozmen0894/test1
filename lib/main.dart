// lib/main.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final Isar? isar;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      isar = null;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      isar = await _openStore(dir.path);
    }

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

    runApp(ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const _App(),
    ));
  }, (error, stack) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(null),
        firebaseReadyProvider.overrideWithValue(false),
      ],
      child: const _App(),
    ));
  });
}

Future<Isar?> _openStore(String directory) async {
  final schemas = [
    LevelProgressSchema,
    DailyRecordSchema,
    StreakRecordSchema,
    CustomLevelSchema,
    AppSettingsSchema,
    OfflineScoreSchema,
  ];
  for (final name in ['wrap_maze_store_v3', 'wrap_maze_store_recovery_v1']) {
    try {
      return await Isar.open(
        schemas,
        directory: directory,
        name: name,
      );
    } catch (_) {}
  }
  return null;
}

class _App extends ConsumerStatefulWidget {
  const _App();
  @override
  ConsumerState<_App> createState() => _AppState();
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
