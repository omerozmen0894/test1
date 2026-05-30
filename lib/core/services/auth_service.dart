import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUidProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'local';
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously(
      {required String displayName}) async {
    final credential = await _auth.signInAnonymously();
    await credential.user?.updateDisplayName(_cleanName(displayName));
    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-login-fields',
        message: 'E-posta ve sifre zorunlu.',
      );
    }
    return _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
  }

  Future<UserCredential> createWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();
    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-register-fields',
        message: 'E-posta ve sifre zorunlu.',
      );
    }
    if (cleanPassword.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Sifre en az 6 karakter olmali.',
      );
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: cleanPassword,
    );
    await credential.user?.updateDisplayName(_cleanName(displayName));
    return credential;
  }

  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(_cleanName(displayName));
    await _auth.currentUser?.reload();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'E-posta zorunlu.',
      );
    }
    await _auth.sendPasswordResetEmail(email: cleanEmail);
  }

  Future<void> requestEmailChange(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'E-posta zorunlu.',
      );
    }
    await _auth.currentUser?.verifyBeforeUpdateEmail(cleanEmail);
  }

  Future<void> signOut() => _auth.signOut();

  String _cleanName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Oyuncu';
    return trimmed.length > 24 ? trimmed.substring(0, 24) : trimmed;
  }
}
