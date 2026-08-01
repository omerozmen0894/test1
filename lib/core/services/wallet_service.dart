import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

final walletServiceProvider = Provider<WalletService>((ref) => WalletService());

final coinBalanceProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(walletServiceProvider).balance(uid);
});

class WalletService {
  static const _coinsKey = 'wrap_maze_coins';

  String _key(String uid) => '${_coinsKey}_$uid';
  String get _deviceKey => '${_coinsKey}_device';

  Future<int> balance(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final userCoins = prefs.getInt(_key(uid)) ?? 0;
    final deviceCoins = prefs.getInt(_deviceKey) ?? 0;
    return userCoins > deviceCoins ? userCoins : deviceCoins;
  }

  Future<int> add(String uid, int amount) async {
    if (amount <= 0) return balance(uid);
    final prefs = await SharedPreferences.getInstance();
    final next = await balance(uid) + amount;
    await _writeSharedBalance(prefs, uid, next);
    return next;
  }

  Future<bool> spend(String uid, int amount) async {
    if (amount <= 0) return true;
    final prefs = await SharedPreferences.getInstance();
    final current = await balance(uid);
    if (current < amount) return false;
    final next = current - amount;
    await _writeSharedBalance(prefs, uid, next);
    return true;
  }

  Future<void> _writeSharedBalance(
    SharedPreferences prefs,
    String uid,
    int value,
  ) async {
    final coinKeys = prefs.getKeys().where((key) => key.startsWith(_coinsKey));
    await Future.wait([
      for (final key in coinKeys) prefs.setInt(key, value),
      prefs.setInt(_key(uid), value),
      prefs.setInt(_deviceKey, value),
    ]);
  }
}
