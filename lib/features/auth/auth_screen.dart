import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/firebase_status_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/streak_service.dart';
import '../game/game_provider.dart';
import '../home/home_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    if (!firebaseReady) return const FirebaseSetupScreen();

    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => AuthScreen(initialError: '$error'),
      data: (user) => user == null
          ? const AuthScreen()
          : _UserProgressScope(uid: user.uid, child: const HomeScreen()),
    );
  }
}

class _UserProgressScope extends ConsumerStatefulWidget {
  final String uid;
  final Widget child;

  const _UserProgressScope({required this.uid, required this.child});

  @override
  ConsumerState<_UserProgressScope> createState() => _UserProgressScopeState();
}

class _UserProgressScopeState extends ConsumerState<_UserProgressScope> {
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _syncUserProgress();
  }

  @override
  void didUpdateWidget(covariant _UserProgressScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _ready = false;
      _syncUserProgress();
    }
  }

  Future<void> _syncUserProgress() async {
    ref.invalidate(completedLevelsProvider);
    ref.invalidate(streakDataProvider);
    ref.invalidate(settingsProvider);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 44, color: scheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Firebase bagli degil',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giris, gercek cok oyunculu oda ve global siralama icin Firebase proje yapilandirmasi gerekiyor.',
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.68)),
                  ),
                  const SizedBox(height: 18),
                  const _SetupLine(
                      'Firebase Console icinde Auth, Firestore ve Realtime Database ac.'),
                  const _SetupLine('Projede flutterfire configure calistir.'),
                  const _SetupLine(
                      'Olusan lib/firebase_options.dart ve platform config dosyalarini ekle.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupLine extends StatelessWidget {
  final String text;
  const _SetupLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  final String? initialError;
  const AuthScreen({super.key, this.initialError});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const _lastEmailKey = 'wrapMaze.lastEmail';
  static const _lastNameKey = 'wrapMaze.lastName';

  final _nameCtrl = TextEditingController(text: 'Oyuncu');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  var _isRegister = false;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
    _loadRememberedLogin();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final lastEmail = prefs.getString(_lastEmailKey);
    final lastName = prefs.getString(_lastNameKey);
    if (lastEmail != null && _emailCtrl.text.isEmpty) {
      _emailCtrl.text = lastEmail;
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      _nameCtrl.text = lastName;
    }
  }

  Future<void> _rememberLogin({String? email, String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email?.trim();
    final cleanName = name?.trim();
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      await prefs.setString(_lastEmailKey, cleanEmail);
    }
    if (cleanName != null && cleanName.isNotEmpty) {
      await prefs.setString(_lastNameKey, cleanName);
    }
  }

  Future<void> _sendPasswordReset() async {
    final service = ref.read(authServiceProvider);
    await _run(() async {
      await service.sendPasswordResetEmail(_emailCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sifre sifirlama baglantisi e-postana gonderildi.'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final service = ref.read(authServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.grid_view_rounded,
                      size: 52, color: scheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Wrap Maze',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Gercek oyuncularla yarismak icin giris yap.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.62)),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isRegister
                        ? Padding(
                            key: const ValueKey('name-field'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Oyuncu adi',
                                prefixIcon: Icon(Icons.person_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-name-field')),
                  ),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.mail_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Sifre',
                      prefixIcon: Icon(Icons.lock_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                          Text(_error!, style: TextStyle(color: scheme.error)),
                    ),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                              if (_isRegister) {
                                await service.createWithEmail(
                                  email: _emailCtrl.text,
                                  password: _passwordCtrl.text,
                                  displayName: _nameCtrl.text,
                                );
                                await _rememberLogin(
                                  email: _emailCtrl.text,
                                  name: _nameCtrl.text,
                                );
                              } else {
                                await service.signInWithEmail(
                                  email: _emailCtrl.text,
                                  password: _passwordCtrl.text,
                                );
                                await _rememberLogin(email: _emailCtrl.text);
                              }
                            }),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegister ? 'Kayit ol' : 'Giris yap'),
                  ),
                  if (!_isRegister)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _sendPasswordReset,
                        child: const Text('Sifremi unuttum'),
                      ),
                    ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister
                        ? 'Zaten hesabim var'
                        : 'Yeni hesap olustur'),
                  ),
                  const Divider(height: 28),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                              await service.signInAnonymously(
                                  displayName: _nameCtrl.text);
                              await _rememberLogin(name: _nameCtrl.text);
                            }),
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('Misafir olarak gir'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('email-already-in-use')) {
      return 'Bu e-posta zaten kayitli.';
    }
    if (text.contains('invalid-email')) return 'E-posta adresi gecersiz.';
    if (text.contains('weak-password')) return 'Sifre en az 6 karakter olmali.';
    if (text.contains('missing-email')) return 'E-posta zorunlu.';
    if (text.contains('user-not-found')) return 'Bu e-posta ile hesap yok.';
    if (text.contains('too-many-requests')) {
      return 'Cok fazla deneme yapildi. Biraz sonra tekrar dene.';
    }
    if (text.contains('missing-login-fields') ||
        text.contains('missing-register-fields')) {
      return 'E-posta ve sifre zorunlu.';
    }
    if (text.contains('wrong-password') ||
        text.contains('invalid-credential')) {
      return 'E-posta veya sifre hatali.';
    }
    return text;
  }
}
