// lib/core/services/iap_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final iapServiceProvider = Provider<IAPService>((ref) {
  final service = IAPService();
  ref.onDispose(service.dispose);
  return service;
});

class ProductIds {
  static const removeAds = 'wrap_maze_remove_ads';
  static const premiumThemes = 'wrap_maze_premium_themes';
  static const premiumBundle = 'wrap_maze_premium_bundle';
  static const hints5 = 'wrap_maze_hints_5';
  static const hints20 = 'wrap_maze_hints_20';
  static const Set<String> all = {
    removeAds,
    premiumThemes,
    premiumBundle,
    hints5,
    hints20,
  };
}

class IAPProduct {
  final String id;
  final String price;
  final String title;
  final bool isOwned;

  const IAPProduct({
    required this.id,
    required this.price,
    required this.title,
    this.isOwned = false,
  });
}

class IAPService {
  final _purchaseController = StreamController<String>.broadcast();

  Stream<String> get onPurchased => _purchaseController.stream;
  bool get isAvailable => false;
  bool get isInitialized => true;
  List<IAPProduct> get products => const [];
  IAPProduct? product(String id) => null;

  Future<void> initialize() async {}
  Future<void> buy(String productId) async {}
  Future<void> restorePurchases() async {}

  void dispose() {
    _purchaseController.close();
  }
}

class IAPScreen extends StatelessWidget {
  const IAPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magaza'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bu surumde uygulama ici satin alma bulunmuyor.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
