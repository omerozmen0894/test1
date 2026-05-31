import 'package:flutter_riverpod/flutter_riverpod.dart';

final adServiceProvider = Provider<AdService>((ref) => AdService());

class AdService {
  Future<void> initialize() async {}
}
