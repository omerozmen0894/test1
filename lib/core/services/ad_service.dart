import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final adServiceProvider = Provider<AdService>((ref) => AdService());

class AdService {
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
}
