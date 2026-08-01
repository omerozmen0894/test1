import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';

import '../../core/database/progress_model.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/theme_model.dart';
import '../../core/providers/isar_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/wallet_service.dart';
import '../game/game_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final l10n = context.l10n;
    final offlineMode = ref.watch(offlineModeProvider);
    final languageCode = ref.watch(languageCodeProvider) ?? 'system';
    final coins = ref.watch(coinBalanceProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings')),
        centerTitle: true,
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (value) => SafeArea(
          top: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
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
                          ? l10n.t('guest_account')
                          : (user?.email ?? l10n.t('no_email'))),
                    ),
                    if (offlineMode) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cloud_sync_rounded),
                        title: Text(l10n.t('sign_in')),
                        subtitle: Text(l10n.t('offline_note')),
                        onTap: () async {
                          await ref
                              .read(offlineModeProvider.notifier)
                              .setOfflineMode(false);
                          ref.invalidate(authStateProvider);
                        },
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.badge_rounded),
                      title: Text(l10n.isTr
                          ? 'Oyuncu adini degistir'
                          : 'Change player name'),
                      onTap: () => _changeDisplayName(context, ref),
                    ),
                    ListTile(
                      leading: const Icon(Icons.alternate_email_rounded),
                      title:
                          Text(l10n.isTr ? 'E-posta degistir' : 'Change email'),
                      subtitle: Text(l10n.isTr
                          ? 'Yeni adrese dogrulama baglantisi gider.'
                          : 'A verification link will be sent to the new address.'),
                      enabled: user != null && !user.isAnonymous,
                      onTap: user != null && !user.isAnonymous
                          ? () => _requestEmailChange(context, ref, user.email)
                          : null,
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded),
                      title: Text(l10n.isTr
                          ? 'Sifre sifirlama e-postasi gonder'
                          : 'Send password reset email'),
                      enabled: user?.email?.isNotEmpty == true,
                      onTap: user?.email?.isNotEmpty == true
                          ? () => _sendPasswordReset(context, ref, user!.email!)
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: Text(l10n.t('logout')),
                      subtitle: Text(l10n.isTr
                          ? 'Giris ekranina don.'
                          : 'Return to sign in.'),
                      onTap: () => _signOut(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Hesabi sil',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(l10n.isTr
                          ? 'Hesap ve bu cihazdaki veriler silinir.'
                          : 'Deletes the account and data on this device.'),
                      enabled: user != null,
                      onTap: user == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AccountDeletionScreen(),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(l10n.t('system_language')),
                      value: 'system',
                      groupValue: languageCode,
                      onChanged: (value) => ref
                          .read(languageCodeProvider.notifier)
                          .setLanguage(value),
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.t('turkish')),
                      value: 'tr',
                      groupValue: languageCode,
                      onChanged: (value) => ref
                          .read(languageCodeProvider.notifier)
                          .setLanguage(value),
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.t('english')),
                      value: 'en',
                      groupValue: languageCode,
                      onChanged: (value) => ref
                          .read(languageCodeProvider.notifier)
                          .setLanguage(value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.t('sound')),
                value: value.soundEnabled,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setSoundEnabled(v),
              ),
              SwitchListTile(
                title: Text(l10n.t('haptics')),
                value: value.hapticsEnabled,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setHapticsEnabled(v),
              ),
              const SizedBox(height: 16),
              _CoinShopCard(
                coins: coins,
                premiumUnlocked: value.premiumUnlocked,
              ),
              const SizedBox(height: 16),
              Text(l10n.t('theme'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...AppThemes.all.map(
                (theme) {
                  return RadioListTile<String>(
                    title: Text('${theme.emoji} ${theme.name}'),
                    value: theme.id,
                    groupValue: value.themeId,
                    onChanged: (id) {
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
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(offlineModeProvider.notifier).setOfflineMode(false);
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(authStateProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(completedLevelsProvider);
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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

class _CoinShopCard extends ConsumerWidget {
  static const unlockCost = 250;

  final int coins;
  final bool premiumUnlocked;

  const _CoinShopCard({
    required this.coins,
    required this.premiumUnlocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final canUnlock = coins >= unlockCost && !premiumUnlocked;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7D6),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.monetization_on_rounded,
                      color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.isTr ? 'Tema marketi' : 'Theme shop',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        l10n.isTr ? '$coins jeton' : '$coins coins',
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.58),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  premiumUnlocked
                      ? Icons.verified_rounded
                      : Icons.lock_open_rounded,
                  color: premiumUnlocked
                      ? const Color(0xFF22C55E)
                      : scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              premiumUnlocked
                  ? (l10n.isTr
                      ? 'Premium temalar acik.'
                      : 'Premium themes are unlocked.')
                  : (l10n.isTr
                      ? '250 jetonla Orman, Gece, Gun Batimi ve Neon temalarini ac.'
                      : 'Unlock Forest, Midnight, Sunset, and Neon themes for 250 coins.'),
              style: TextStyle(color: scheme.onSurface.withOpacity(0.68)),
            ),
            if (!premiumUnlocked) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: canUnlock
                    ? () async {
                        final uid = ref.read(currentUidProvider);
                        final spent = await ref
                            .read(walletServiceProvider)
                            .spend(uid, unlockCost);
                        if (!spent) return;
                        await ref
                            .read(settingsProvider.notifier)
                            .setPremiumUnlocked(true);
                        ref.invalidate(coinBalanceProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.isTr
                                ? 'Premium temalar acildi.'
                                : 'Premium themes unlocked.'),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.auto_awesome_rounded),
                label:
                    Text(l10n.isTr ? '250 jetonla ac' : 'Unlock for 250 coins'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _passwordCtrl = TextEditingController();
  var _confirmed = false;
  var _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).valueOrNull;
    final needsPassword = user != null && !user.isAnonymous;
    final canDelete = _confirmed &&
        !_loading &&
        (!needsPassword || _passwordCtrl.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Hesabi sil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: scheme.error,
              size: 44,
            ),
            const SizedBox(height: 16),
            const Text(
              'Hesabini kalici olarak sil',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu islem Firebase hesabini, bu cihazdaki bolum ilerlemeni, gunluk seri kayitlarini, ayarlarini ve olusturdugun yerel labirentleri siler.',
              style: TextStyle(color: scheme.onSurface.withOpacity(0.68)),
            ),
            const SizedBox(height: 20),
            if (needsPassword)
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Sifre',
                  prefixIcon: Icon(Icons.lock_rounded),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (needsPassword) const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: const Text('Bu islemin geri alinamayacagini anliyorum.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: canDelete ? () => _deleteAccount(user) : null,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_rounded),
              label: const Text('Hesabimi sil'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(User? user) async {
    if (user == null) return;
    setState(() => _loading = true);
    final uid = user.uid;
    try {
      await ref.read(authServiceProvider).deleteCurrentAccount(
            password: _passwordCtrl.text,
          );
      await _deleteLocalUserData(uid);
      ref.invalidate(authStateProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(completedLevelsProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesap silindi.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showDeleteError(context, error);
    }
  }

  Future<void> _deleteLocalUserData(String uid) async {
    await deleteCompletedLevelFallback(uid);
    await deleteAllCompletedLevelFallback();
    final isar = ref.read(isarProvider);
    if (isar == null) return;
    await isar.writeTxn(() async {
      final levelIds =
          (await isar.levelProgress.filter().uidEqualTo(uid).findAll())
              .map((item) => item.id)
              .toList();
      final dailyIds =
          (await isar.dailyRecords.filter().uidEqualTo(uid).findAll())
              .map((item) => item.id)
              .toList();
      final streakIds =
          (await isar.streakRecords.filter().uidEqualTo(uid).findAll())
              .map((item) => item.id)
              .toList();
      final customIds =
          (await isar.customLevels.filter().uidEqualTo(uid).findAll())
              .map((item) => item.id)
              .toList();
      final settingsIds =
          (await isar.appSettings.filter().uidEqualTo(uid).findAll())
              .map((item) => item.id)
              .toList();

      await isar.levelProgress.deleteAll(levelIds);
      await isar.dailyRecords.deleteAll(dailyIds);
      await isar.streakRecords.deleteAll(streakIds);
      await isar.customLevels.deleteAll(customIds);
      await isar.appSettings.deleteAll(settingsIds);
    });
  }

  void _showDeleteError(BuildContext context, Object error) {
    final text = error.toString();
    final message = text.contains('requires-recent-login')
        ? 'Guvenlik icin tekrar giris yapip yeniden dene.'
        : text.contains('wrong-password') || text.contains('invalid-credential')
            ? 'Sifre hatali.'
            : 'Hesap silinemedi: $error';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
