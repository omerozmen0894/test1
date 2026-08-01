import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languagePrefsKey = 'wrapMaze.languageCode.v1';
const _offlineModePrefsKey = 'wrapMaze.offlineMode.v1';

final languageCodeProvider =
    StateNotifierProvider<LanguageCodeNotifier, String?>(
  (ref) => LanguageCodeNotifier()..load(),
);

final offlineModeProvider = StateNotifierProvider<OfflineModeNotifier, bool>(
  (ref) => OfflineModeNotifier()..load(),
);

class LanguageCodeNotifier extends StateNotifier<String?> {
  LanguageCodeNotifier() : super(null);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languagePrefsKey);
    if (code == 'tr' || code == 'en') state = code;
  }

  Future<void> setLanguage(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null || code == 'system') {
      await prefs.remove(_languagePrefsKey);
      state = null;
      return;
    }
    await prefs.setString(_languagePrefsKey, code);
    state = code;
  }
}

class OfflineModeNotifier extends StateNotifier<bool> {
  OfflineModeNotifier() : super(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_offlineModePrefsKey) ?? false;
  }

  Future<void> setOfflineMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModePrefsKey, value);
    state = value;
  }
}

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('tr'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('tr'));
  }

  bool get isTr => locale.languageCode == 'tr';

  String t(String key) {
    return (_values[locale.languageCode] ?? _values['tr']!)[key] ??
        _values['tr']![key] ??
        key;
  }

  String level(int level) => isTr ? 'Bolum $level' : 'Level $level';
  String endlessLevel(int level) => isTr ? 'Sonsuz $level' : 'Endless $level';
  String moves(int moves) => isTr ? '$moves hamle' : '$moves moves';
  String reward(int reward, int coins) => isTr
      ? '+$reward jeton  \u00B7  Toplam $coins'
      : '+$reward coins  \u00B7  Total $coins';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['tr', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final code = isSupported(locale) ? locale.languageCode : 'tr';
    return AppLocalizations(Locale(code));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

const _values = {
  'tr': {
    'app_title': 'Wrap Maze',
    'tagline': 'Sarmala \u00B7 coz \u00B7 yaris',
    'sign_in_pitch': 'Gercek oyuncularla yarismak icin giris yap.',
    'player_name': 'Oyuncu adi',
    'email': 'E-posta',
    'password': 'Sifre',
    'sign_in': 'Giris yap',
    'register': 'Kayit ol',
    'forgot_password': 'Sifremi unuttum',
    'have_account': 'Zaten hesabim var',
    'new_account': 'Yeni hesap olustur',
    'guest': 'Misafir olarak gir',
    'offline_play': 'Internetsiz oyna',
    'offline_note': 'Bolumler ve ilerlemen bu cihazda kaydedilir.',
    'settings': 'Ayarlar',
    'logout': 'Cikis yap',
    'sound': 'Ses',
    'haptics': 'Titresim',
    'theme': 'Tema',
    'language': 'Dil',
    'system_language': 'Sistem dili',
    'turkish': 'Turkce',
    'english': 'English',
    'home_endless': 'Sonsuz',
    'home_multiplayer': 'Cok Oyunculu',
    'home_daily': 'Gunluk',
    'home_streak': 'Streak',
    'home_leaderboard': 'Siralama',
    'home_local': 'Yerel',
    'home_editor': 'Editor',
    'daily_quests': 'Gunluk gorevler',
    'levels': 'Bolumler',
    'continue_level': 'Kaldigin yerden devam et',
    'all_levels_done': 'Tum bolumler tamamlandi',
    'replay_final_level': 'Son bolumu tekrar oyna',
    'completed': 'Tamamlanan',
    'total': 'Toplam',
    'rate': 'Oran',
    'series': 'Seri',
    'moves_label': 'Hamle',
    'progress_label': 'Ilerleme',
    'hint': 'Ipucu',
    'undo': 'Geri al',
    'rewind': 'Geri',
    'freeze': 'Dondur',
    'cleanse': 'Temizle',
    'how_to_play': 'Nasil oynanir?',
    'tutorial_paint_title': 'Tum kareleri boya',
    'tutorial_paint_text':
        'Mor rotayi acik karelerin tamamindan gecir. Ayni kareye geri donme.',
    'tutorial_target_title': 'HEDEF en son',
    'tutorial_target_text':
        'Turuncu hedefe erken girme. Once alani doldur, sonra hedefe ulas.',
    'tutorial_controls_title': 'Kaydir veya yon tuslarini kullan',
    'tutorial_controls_text':
        'Alttaki yon tuslari ve ekranda kaydirma ayni sekilde calisir.',
    'tutorial_hint_title': 'Takilirsan ipucu al',
    'tutorial_hint_text':
        'Ipucu onerilen kareyi gosterir. Sonraki bolumlerde anahtar, tuzak ve takip gelir.',
    'menu': 'Menu',
    'next_level': 'Sonraki bolum',
    'level_done': 'Bolum tamamlandi',
    'start': 'Basla',
    'skip': 'Gec',
    'perfect_route': 'Kusursuz Rota',
    'fill_all': 'Tum kareleri boya',
    'key_exit': 'Anahtarlarla cikisa ulas',
    'crystals': 'Kristalleri sirayla topla',
    'avoid_traps': 'Tuzaklardan kac',
    'boss': 'Boss baskisindan kac',
    'local_player': 'Yerel oyuncu',
    'no_email': 'E-posta yok',
    'guest_account': 'Misafir hesap',
  },
  'en': {
    'app_title': 'Wrap Maze',
    'tagline': 'wrap \u00B7 solve \u00B7 race',
    'sign_in_pitch': 'Sign in to race with real players.',
    'player_name': 'Player name',
    'email': 'Email',
    'password': 'Password',
    'sign_in': 'Sign in',
    'register': 'Create account',
    'forgot_password': 'Forgot password',
    'have_account': 'I already have an account',
    'new_account': 'Create a new account',
    'guest': 'Continue as guest',
    'offline_play': 'Play offline',
    'offline_note': 'Levels and progress are saved on this device.',
    'settings': 'Settings',
    'logout': 'Sign out',
    'sound': 'Sound',
    'haptics': 'Haptics',
    'theme': 'Theme',
    'language': 'Language',
    'system_language': 'System language',
    'turkish': 'Turkish',
    'english': 'English',
    'home_endless': 'Endless',
    'home_multiplayer': 'Multiplayer',
    'home_daily': 'Daily',
    'home_streak': 'Streak',
    'home_leaderboard': 'Leaderboard',
    'home_local': 'Local',
    'home_editor': 'Editor',
    'daily_quests': 'Daily quests',
    'levels': 'Levels',
    'continue_level': 'Continue where you left off',
    'all_levels_done': 'All levels complete',
    'replay_final_level': 'Replay the final level',
    'completed': 'Completed',
    'total': 'Total',
    'rate': 'Rate',
    'series': 'Streak',
    'moves_label': 'Moves',
    'progress_label': 'Progress',
    'hint': 'Hint',
    'undo': 'Undo',
    'rewind': 'Undo',
    'freeze': 'Freeze',
    'cleanse': 'Clean',
    'how_to_play': 'How to play',
    'tutorial_paint_title': 'Paint every tile',
    'tutorial_paint_text':
        'Draw the purple route through every open tile. Do not step on the same tile twice.',
    'tutorial_target_title': 'Target comes last',
    'tutorial_target_text':
        'Do not enter the orange target early. Fill the board first, then reach the target.',
    'tutorial_controls_title': 'Swipe or use direction buttons',
    'tutorial_controls_text':
        'The buttons below and swipe controls move the player the same way.',
    'tutorial_hint_title': 'Use a hint if stuck',
    'tutorial_hint_text':
        'Hints show the suggested next tile. Later levels add keys, traps, and chase pressure.',
    'menu': 'Menu',
    'next_level': 'Next level',
    'level_done': 'Level complete',
    'start': 'Start',
    'skip': 'Skip',
    'perfect_route': 'Perfect Route',
    'fill_all': 'Paint every tile',
    'key_exit': 'Collect keys and reach the exit',
    'crystals': 'Collect crystals in order',
    'avoid_traps': 'Avoid traps',
    'boss': 'Escape the boss pressure',
    'local_player': 'Local player',
    'no_email': 'No email',
    'guest_account': 'Guest account',
  },
};

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
