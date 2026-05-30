import 'package:flutter_riverpod/flutter_riverpod.dart';

final playGamesProvider = Provider<PlayGamesService>((ref) => PlayGamesService());

class PlayGamesService {
  Future<void> signIn() async {}
}
