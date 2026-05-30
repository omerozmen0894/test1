// lib/core/services/iap_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:isar/isar.dart';
import '../database/progress_model.dart';
import '../providers/isar_provider.dart';
import 'auth_service.dart';

final iapServiceProvider = Provider<IAPService>((ref) {
  final service =
      IAPService(ref.read(isarProvider), ref.watch(currentUidProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Ürün ID'leri — Google Play Console'da tanımlanmalı
class ProductIds {
  /// Tek seferlik satın alımlar
  static const removeAds = 'wrap_maze_remove_ads';
  static const premiumThemes = 'wrap_maze_premium_themes';
  static const premiumBundle = 'wrap_maze_premium_bundle'; // ikisi birden ucuz

  /// Tüketilebilir (hint hakkı)
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
  final ProductDetails details;
  final bool isOwned;

  const IAPProduct({required this.details, required this.isOwned});
  String get id => details.id;
  String get price => details.price;
  String get title => details.title;
}

class IAPService {
  final Isar _isar;
  final String _uid;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _products = <String, IAPProduct>{};
  var _available = false;
  var _initialized = false;
  final _purchaseController = StreamController<String>.broadcast();

  IAPService(this._isar, this._uid);

  Stream<String> get onPurchased => _purchaseController.stream;
  bool get isAvailable => _available;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    final bool available;
    try {
      available = await InAppPurchase.instance.isAvailable();
    } catch (_) {
      _initialized = true;
      return;
    }
    _available = available;
    if (!available) {
      _initialized = true;
      return;
    }

    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchase);
    await _loadProducts();
    _initialized = true;
  }

  Future<void> _loadProducts() async {
    final response =
        await InAppPurchase.instance.queryProductDetails(ProductIds.all);
    for (final d in response.productDetails) {
      _products[d.id] = IAPProduct(details: d, isOwned: false);
    }
  }

  List<IAPProduct> get products => _products.values.toList();
  IAPProduct? product(String id) => _products[id];

  Future<void> buy(String productId) async {
    final p = _products[productId];
    if (p == null) {
      throw StateError('Urun magazadan yuklenemedi: $productId');
    }

    final consumable =
        productId == ProductIds.hints5 || productId == ProductIds.hints20;

    final param = consumable
        ? PurchaseParam(productDetails: p.details)
        : PurchaseParam(productDetails: p.details);

    if (consumable) {
      await InAppPurchase.instance.buyConsumable(purchaseParam: param);
    } else {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  void _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _handlePurchased(p);
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
      }
    }
  }

  Future<void> _handlePurchased(PurchaseDetails p) async {
    await _isar.writeTxn(() async {
      final s = await _isar.appSettings.filter().uidEqualTo(_uid).findFirst() ??
          AppSettings.defaults(_uid);
      switch (p.productID) {
        case ProductIds.removeAds:
          s.adsRemoved = true;
        case ProductIds.premiumThemes:
          s.premiumUnlocked = true;
        case ProductIds.premiumBundle:
          s.adsRemoved = true;
          s.premiumUnlocked = true;
        case ProductIds.hints5:
          s.totalHints = (s.totalHints) + 5;
        case ProductIds.hints20:
          s.totalHints = (s.totalHints) + 20;
      }
      await _isar.appSettings.put(s);
    });
    _purchaseController.add(p.productID);
  }

  void dispose() {
    _sub?.cancel();
    _purchaseController.close();
  }
}

// ─── IAP Satın Alma Ekranı ────────────────────────────────────────────────────

class IAPScreen extends ConsumerStatefulWidget {
  const IAPScreen({super.key});
  @override
  ConsumerState<IAPScreen> createState() => _IAPScreenState();
}

class _IAPScreenState extends ConsumerState<IAPScreen> {
  var _busyProductId = '';
  String? _message;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(iapServiceProvider).initialize());
  }

  Future<void> _buy(String productId) async {
    setState(() {
      _busyProductId = productId;
      _message = null;
    });
    try {
      await ref.read(iapServiceProvider).buy(productId);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Urun henuz magazada aktif degil veya yuklenemedi. Urun ID: $productId');
      }
    } finally {
      if (mounted) setState(() => _busyProductId = '');
    }
  }

  Future<void> _restore() async {
    setState(() => _message = null);
    try {
      await ref.read(iapServiceProvider).restorePurchases();
      if (mounted) setState(() => _message = 'Satin alimlar kontrol edildi.');
    } catch (_) {
      if (mounted) setState(() => _message = 'Geri yukleme baslatilamadi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iap = ref.watch(iapServiceProvider);
    String priceOf(String id, String fallback) =>
        iap.product(id)?.price ?? fallback;
    VoidCallback? buyAction(String id) =>
        _busyProductId.isEmpty ? () => _buy(id) : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Premium',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('👑', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text('Wrap Maze Premium',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimary)),
                const SizedBox(height: 6),
                Text('Tüm özelliklerin kilidini aç',
                    style: TextStyle(
                        fontSize: 14,
                        color: scheme.onPrimary.withOpacity(0.8))),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Özellik listesi
          ...[
            ('🚫', 'Reklamsız Deneyim', 'Hiç reklam görmeden oyna'),
            ('🎨', '6 Premium Tema', 'Orman, Gece Yarısı, Gün Batımı, Neon'),
            ('💡', 'Sınırsız İpucu', 'Her seviyede çözüm yolunu gör'),
            ('📅', 'Günlük Rozet', 'Streak rozetleri koleksiyonu'),
          ].map((f) => _FeatureRow(emoji: f.$1, title: f.$2, desc: f.$3)),

          const SizedBox(height: 24),

          // Satın alma seçenekleri
          _PriceCard(
            title: '🚫 Reklamları Kaldır',
            price: priceOf(ProductIds.removeAds, 'Magaza fiyati'),
            desc: 'Tek seferlik ödeme',
            loading: _busyProductId == ProductIds.removeAds,
            onTap: buyAction(ProductIds.removeAds),
          ),
          const SizedBox(height: 10),
          _PriceCard(
            title: '🎨 Premium Temalar',
            price: priceOf(ProductIds.premiumThemes, 'Magaza fiyati'),
            desc: '6 ekstra tema + yeni temalar otomatik',
            loading: _busyProductId == ProductIds.premiumThemes,
            onTap: buyAction(ProductIds.premiumThemes),
          ),
          const SizedBox(height: 10),
          _PriceCard(
            title: '👑 Premium Bundle',
            price: priceOf(ProductIds.premiumBundle, 'Magaza fiyati'),
            desc: 'Her şey dahil — %20 tasarruf',
            highlighted: true,
            loading: _busyProductId == ProductIds.premiumBundle,
            onTap: buyAction(ProductIds.premiumBundle),
          ),
          const SizedBox(height: 10),
          _PriceCard(
            title: '💡 5 İpucu Hakkı',
            price: priceOf(ProductIds.hints5, 'Magaza fiyati'),
            desc: 'Tüketilebilir, istediğinde kullan',
            loading: _busyProductId == ProductIds.hints5,
            onTap: buyAction(ProductIds.hints5),
          ),
          const SizedBox(height: 10),
          _PriceCard(
            title: '💡 20 İpucu Hakkı',
            price: priceOf(ProductIds.hints20, 'Magaza fiyati'),
            desc: '%25 daha ucuz paket',
            loading: _busyProductId == ProductIds.hints20,
            onTap: buyAction(ProductIds.hints20),
          ),

          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _busyProductId.isEmpty ? _restore : null,
              child: Text('Satın Alımları Geri Yükle',
                  style: TextStyle(color: scheme.primary)),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 6),
            Text(
              _message!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Satın alımlar Google Play hesabınıza bağlıdır.',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurface.withOpacity(0.4)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String emoji, title, desc;
  const _FeatureRow(
      {required this.emoji, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(desc,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55))),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String title, price, desc;
  final bool highlighted;
  final bool loading;
  final VoidCallback? onTap;

  const _PriceCard({
    required this.title,
    required this.price,
    required this.desc,
    required this.onTap,
    this.highlighted = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlighted ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                highlighted ? scheme.primary : scheme.outline.withOpacity(0.2),
            width: highlighted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlighted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('EN POPÜLER',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimary)),
                    ),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary)),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Al', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
