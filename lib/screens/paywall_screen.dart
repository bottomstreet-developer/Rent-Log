import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchase_service.dart';
import '../widgets/app_chrome.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;
  bool _pricesLoading = true;
  String _monthlyButtonText = 'Monthly: \$2.99/mo';
  String _yearlyButtonText = 'Yearly: \$19.99/yr';

  static const String _monthlyProductId = 'rentlog_pro_monthly';
  static const String _yearlyProductId = 'rentlog_pro_yearly';

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _pricesLoading = true);
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      StoreProduct? monthly;
      StoreProduct? yearly;
      if (offering != null) {
        for (final package in offering.availablePackages) {
          final p = package.storeProduct;
          if (p.identifier == _monthlyProductId) monthly = p;
          if (p.identifier == _yearlyProductId) yearly = p;
        }
      }
      if (!mounted) return;
      if (monthly != null && yearly != null) {
        final m = monthly;
        final y = yearly;
        final save = _savingsPercent(m, y);
        setState(() {
          _pricesLoading = false;
          _monthlyButtonText = 'Monthly: ${m.priceString}/mo';
          _yearlyButtonText = save != null
              ? 'Yearly: ${y.priceString}/yr (save $save%)'
              : 'Yearly: ${y.priceString}/yr';
        });
      } else {
        _applyPriceFallback();
      }
    } catch (_) {
      _applyPriceFallback();
    }
  }

  void _applyPriceFallback() {
    if (!mounted) return;
    setState(() {
      _pricesLoading = false;
      _monthlyButtonText = 'Monthly: \$2.99/mo';
      _yearlyButtonText = 'Yearly: \$19.99/yr';
    });
  }

  int? _savingsPercent(StoreProduct monthly, StoreProduct yearly) {
    final annual = monthly.price * 12;
    if (annual <= 0) return null;
    final pct = ((annual - yearly.price) / annual * 100).round();
    if (pct <= 0) return null;
    return pct;
  }

  Future<void> _buy(bool yearly) async {
    setState(() => _loading = true);
    final ok = yearly
        ? await PurchaseService.purchaseYearly()
        : await PurchaseService.purchaseMonthly();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context, true);
  }

  Widget _planButtonLabel({
    required String planName,
    required String resolvedText,
  }) {
    if (_pricesLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            planName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      );
    }
    return Text(resolvedText);
  }

  Widget _compactPaywallFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.star, size: 14, color: Color(0xFF00C48C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Upgrade to Pro',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: premiumCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/icon/icon.png',
                            width: 64,
                            height: 64,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'RentLog Pro',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Everything you need to manage your rent, protected and backed up.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF8A8A8A),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _compactPaywallFeature('Multiple properties'),
                      _compactPaywallFeature('PDF export'),
                      _compactPaywallFeature('Full payment history'),
                      _compactPaywallFeature('Cloud Backup'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C48C),
                              ),
                              onPressed: (_loading || _pricesLoading) ? null : () => _buy(false),
                              child: _planButtonLabel(
                                planName: 'Monthly',
                                resolvedText: _monthlyButtonText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C48C),
                              ),
                              onPressed: (_loading || _pricesLoading) ? null : () => _buy(true),
                              child: _planButtonLabel(
                                planName: 'Yearly',
                                resolvedText: _yearlyButtonText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8A8A8A),
                        ),
                        child: const Text('Maybe later'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                final ok = await PurchaseService.restorePurchases();
                                if (!context.mounted) return;
                                if (ok) Navigator.pop(context, true);
                              },
                        child: const Text('Restore purchases'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
