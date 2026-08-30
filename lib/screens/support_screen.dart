import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization.dart';
import '../theme/app_tokens.dart';
import '../core/melodi_design.dart';
import '../core/constants.dart';

/// Donation / "purchase" screen. The app is free and ad-free; supporters can
/// leave an optional tip through an Apple-regulated in-app purchase (StoreKit).
/// No app functionality is locked behind this — it is purely a support gesture.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // These product ids must be created in App Store Connect as Consumable
  // "Tip" products before the store can return prices for them.
  static const List<String> _productIds = [
    'melodi_tip_small',
    'melodi_tip_medium',
    'melodi_tip_large',
  ];

  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  List<ProductDetails> _products = const [];
  bool _storeAvailable = false;
  bool _loading = true;
  String? _error;
  final Set<String> _pending = {};

  String _t(String tr, String en, String de) {
    switch (AppLocale.currentLocale) {
      case 'en':
        return en;
      case 'de':
        return de;
      default:
        return tr;
    }
  }

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(
      _handlePurchase,
      onDone: _subscription.cancel,
      onError: (_) {},
    );
    _loadStore();
  }

  Future<void> _loadStore() async {
    try {
      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) {
        final response = await _iap.queryProductDetails(_productIds.toSet());
        if (!mounted) return;
        setState(() {
          _products = response.productDetails;
          _error = response.error?.message;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _handlePurchase(List<PurchaseDetails> details) {
    for (final detail in details) {
      switch (detail.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _pending.add(detail.productID));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (detail.pendingCompletePurchase) {
            _iap.completePurchase(detail);
          }
          if (!mounted) return;
          setState(() => _pending.remove(detail.productID));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('Teşekkürler! 💚', 'Thank you! 💚', 'Danke! 💚')),
            ),
          );
        case PurchaseStatus.error:
          if (!mounted) return;
          setState(() => _pending.remove(detail.productID));
        default:
          if (!mounted) return;
          setState(() => _pending.remove(detail.productID));
      }
    }
  }

  Future<void> _buy(ProductDetails product) async {
    try {
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _restore() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openExternalSupport() async {
    final uri = Uri.parse('https://github.com/safakmert0/melodi');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Destek Ol', 'Support', 'Unterstützen')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: Icon(
              Icons.volunteer_activism_rounded,
              size: 64,
              color: MelodiTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t('Melodi’yi destekle', 'Support Melodi', 'Unterstütze Melodi'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              'Melodi tamamen ücretsiz ve reklamsızdır. İstersen bir bağış (satın alma) yaparak '
              'geliştirmeyi destekleyebilirsin. Ödeme Apple üzerinden güvenle gerçekleşir; '
              'karşılığında kilitli bir özellik açılmaz, bu bir destek jestidir.',
              'Melodi is completely free and ad-free. You can optionally leave a tip (in-app '
              'purchase) to support development. Payment is handled securely by Apple; no feature '
              'is unlocked — it is simply a gesture of support.',
              'Melodi ist völlig kostenlos und werbefrei. Du kannst optional ein Trinkgeld (In-App-Kauf) '
              'geben, um die Entwicklung zu unterstützen. Die Zahlung läuft sicher über Apple; es wird '
              'keine Funktion freigeschaltet — es ist eine Geste der Unterstützung.',
            ),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (!_storeAvailable)
            Column(
              children: [
                _infoCard(
                  _t(
                    'Mağaza şu anda kullanılamıyor. Bu, sideload (AltStore/Sideloadly) sürümünde normaldir. App Store sürümünde bağışlar Apple üzerinden çalışır.',
                    'The store is unavailable right now. This is normal on sideloaded builds (AltStore/Sideloadly). Tips work via Apple on the App Store build.',
                    'Der Store ist derzeit nicht verfügbar. Das ist normal bei Sideload-Builds. Spenden funktionieren über Apple im App Store Build.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadStore,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_t('Tekrar dene', 'Retry', 'Erneut versuchen')),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openExternalSupport,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(_t('GitHub’da destekle', 'Support on GitHub', 'Auf GitHub unterstützen')),
                ),
              ],
            )
          else if (_products.isEmpty)
            Column(
              children: [
                _infoCard(
                  _t(
                    'Bağış ürünleri henüz yapılandırılmamış. Geliştirici, App Store Connect’te '
                    'ürünleri eklemeli.',
                    'No donation products are configured yet. The developer must add them in '
                    'App Store Connect.',
                    'Noch keine Spendenprodukte konfiguriert. Der Entwickler muss sie in '
                    'App Store Connect anlegen.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadStore,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_t('Yenile', 'Refresh', 'Aktualisieren')),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openExternalSupport,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(_t('GitHub’da destekle', 'Support on GitHub', 'Auf GitHub unterstützen')),
                ),
              ],
            )
          else
            ..._products.map(_buildTier),
          if (!_loading && _storeAvailable && _products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: _restore,
                child: Text(_t(
                  'Önceki bağışları geri yükle',
                  'Restore previous tips',
                  'Frühere Spenden wiederherstellen',
                )),
              ),
            ),
          if (_error != null && _error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTier(ProductDetails product) {
    final buying = _pending.contains(product.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.tonal(
        onPressed: buying ? null : () => _buy(product),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        ),
        child: Row(
          children: [
            Icon(Icons.favorite_rounded, color: MelodiTheme.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t('Bağış yap', 'Leave a tip', 'Spende geben'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (buying)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                product.price,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.tokens.radiusControl),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
