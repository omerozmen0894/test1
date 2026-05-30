import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/theme_model.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle_rounded),
                    title: Text(user?.displayName?.trim().isNotEmpty == true
                        ? user!.displayName!
                        : value.displayName),
                    subtitle: Text(user?.isAnonymous == true
                        ? 'Misafir hesap'
                        : (user?.email ?? 'E-posta yok')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_rounded),
                    title: const Text('Oyuncu adini degistir'),
                    onTap: () => _changeDisplayName(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.alternate_email_rounded),
                    title: const Text('E-posta degistir'),
                    subtitle:
                        const Text('Yeni adrese dogrulama baglantisi gider.'),
                    enabled: user != null && !user.isAnonymous,
                    onTap: user != null && !user.isAnonymous
                        ? () => _requestEmailChange(context, ref, user.email)
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Sifre sifirlama e-postasi gonder'),
                    enabled: user?.email?.isNotEmpty == true,
                    onTap: user?.email?.isNotEmpty == true
                        ? () => _sendPasswordReset(context, ref, user!.email!)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Ses'),
              value: value.soundEnabled,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setSoundEnabled(v),
            ),
            SwitchListTile(
              title: const Text('Titreşim'),
              value: value.hapticsEnabled,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setHapticsEnabled(v),
            ),
            const SizedBox(height: 16),
            const Text('Tema', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...AppThemes.all.map(
              (theme) {
                final locked = theme.isPremium && !value.premiumUnlocked;
                return RadioListTile<String>(
                  title: Text(
                      '${theme.emoji} ${theme.name}${locked ? '  Premium' : ''}'),
                  value: theme.id,
                  groupValue: value.themeId,
                  onChanged: (id) {
                    if (locked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bu tema icin Premium gerekli.'),
                        ),
                      );
                      return;
                    }
                    if (id != null) {
                      ref.read(settingsProvider.notifier).setTheme(id);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeDisplayName(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authServiceProvider);
    final settings = ref.read(settingsProvider).valueOrNull;
    final controller = TextEditingController(
      text: auth.currentUser?.displayName ?? settings?.displayName ?? 'Oyuncu',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oyuncu adi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'Yeni ad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await auth.updateDisplayName(name);
      await ref.read(settingsProvider.notifier).setDisplayName(name.trim());
      ref.invalidate(authStateProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyuncu adi guncellendi.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error);
    }
  }

  Future<void> _requestEmailChange(
    BuildContext context,
    WidgetRef ref,
    String? currentEmail,
  ) async {
    final controller = TextEditingController(text: currentEmail ?? '');
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('E-posta degistir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Yeni e-posta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Baglanti gonder'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty) return;
    try {
      await ref.read(authServiceProvider).requestEmailChange(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dogrulama baglantisi yeni e-postana gonderildi.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error);
    }
  }

  Future<void> _sendPasswordReset(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sifre sifirlama e-postasi gonderildi.')),
      );
    } catch (error) {
      _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    final text = error.toString();
    final message = text.contains('requires-recent-login')
        ? 'Bu islem icin yeniden giris yapman gerekiyor.'
        : text.contains('invalid-email')
            ? 'E-posta adresi gecersiz.'
            : text.contains('missing-email')
                ? 'E-posta zorunlu.'
                : 'Islem tamamlanamadi: $error';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
