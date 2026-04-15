import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/purchase_service.dart';

int? rentlogProPlanSheetSavingsPct(StoreProduct monthly, StoreProduct yearly) {
  final annual = monthly.price * 12;
  if (annual <= 0) return null;
  final pct = ((annual - yearly.price) / annual * 100).round();
  if (pct <= 0) return null;
  return pct;
}

class RentlogProPlanSheet extends StatefulWidget {
  const RentlogProPlanSheet({
    super.key,
    required this.isParentMounted,
    required this.ctaColor,
    required this.onUnlocked,
    required this.onRestoreComplete,
  });

  final bool Function() isParentMounted;
  final Color ctaColor;
  final Future<void> Function() onUnlocked;
  final Future<void> Function(bool restoredPro) onRestoreComplete;

  @override
  State<RentlogProPlanSheet> createState() => _RentlogProPlanSheetState();
}

class _RentlogProPlanSheetState extends State<RentlogProPlanSheet> {
  static const String _monthlyProductId = 'rentlog_pro_monthly';
  static const String _yearlyProductId = 'rentlog_pro_yearly';

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

  String _selectedPlan = 'yearly';
  bool _isPurchasing = false;
  bool _pricesLoading = true;
  String _monthlySubtitle = '...';
  String _yearlySubtitle = '...';
  int? _savePct;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    if (!mounted) return;
    setState(() => _pricesLoading = true);

    StoreProduct? monthly;
    StoreProduct? yearly;

    // Pass 1: try configured offering
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering != null) {
        for (final package in offering.availablePackages) {
          final p = package.storeProduct;
          if (p.identifier == _monthlyProductId) monthly = p;
          if (p.identifier == _yearlyProductId) yearly = p;
        }
      }
    } catch (_) {}

    // Pass 2: direct product fetch (Android fallback for unconfigured offerings)
    if (monthly == null || yearly == null) {
      try {
        final products = await Purchases.getProducts(
          [_monthlyProductId, _yearlyProductId],
        );
        for (final p in products) {
          if (p.identifier == _monthlyProductId) monthly ??= p;
          if (p.identifier == _yearlyProductId) yearly ??= p;
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (monthly != null && yearly != null) {
      final m = monthly!;
      final y = yearly!;
      setState(() {
        _pricesLoading = false;
        _monthlySubtitle = '${m.priceString}/mo';
        _yearlySubtitle = '${y.priceString}/yr';
        _savePct = rentlogProPlanSheetSavingsPct(m, y);
      });
    } else {
      _applyFallback();
    }
  }

  void _applyFallback() {
    if (!mounted) return;
    setState(() {
      _pricesLoading = false;
      _monthlySubtitle = '\$2.99/mo';
      _yearlySubtitle = '\$19.99/yr';
      _savePct = 44;
    });
  }

  Widget _priceLine(TextStyle style, {required bool yearly}) {
    if (_pricesLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: style.color,
          ),
        ),
      );
    }
    return Text(
      yearly ? _yearlySubtitle : _monthlySubtitle,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Everything you need to manage your rent, protected and backed up.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF8A8A8A),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _compactPaywallFeature('Multiple properties'),
          _compactPaywallFeature('PDF export'),
          _compactPaywallFeature('Full payment history'),
          _compactPaywallFeature('Cloud Backup'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPlan = 'yearly'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedPlan == 'yearly'
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedPlan == 'yearly'
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFE4E6EA),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Yearly',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedPlan == 'yearly'
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  _priceLine(
                                    TextStyle(
                                      fontSize: 13,
                                      color: _selectedPlan == 'yearly'
                                          ? const Color(0xAAFFFFFF)
                                          : const Color(0xFF8A8A8A),
                                    ),
                                    yearly: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_savePct != null && !_pricesLoading)
                        Positioned(
                          top: 6,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C48C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Save $_savePct%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPlan = 'monthly'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedPlan == 'monthly'
                          ? const Color(0xFF1A1A1A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedPlan == 'monthly'
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFE4E6EA),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _selectedPlan == 'monthly'
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            _priceLine(
                              TextStyle(
                                fontSize: 13,
                                color: _selectedPlan == 'monthly'
                                    ? const Color(0xAAFFFFFF)
                                    : const Color(0xFF8A8A8A),
                              ),
                              yearly: false,
                            ),
                          ],
                        ),
                        Icon(
                          _selectedPlan == 'monthly'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: _selectedPlan == 'monthly'
                              ? Colors.white
                              : const Color(0xFFCCCCCC),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isPurchasing
                ? null
                : () async {
                    setState(() => _isPurchasing = true);
                    try {
                      final yearly = _selectedPlan == 'yearly';
                      final unlocked = yearly
                          ? await PurchaseService.purchaseYearly() == true
                          : await PurchaseService.purchaseMonthly() == true;
                      if (unlocked) {
                        if (!context.mounted) return;
                        Navigator.pop(context, true);
                        if (widget.isParentMounted()) {
                          await widget.onUnlocked();
                        }
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isPurchasing = false);
                      }
                    }
                  },
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: widget.ctaColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _isPurchasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _selectedPlan == 'yearly'
                            ? 'Continue with Yearly'
                            : 'Continue with Monthly',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8A8A8A),
            ),
            child: const Text('Maybe later'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  final restoredPro =
                      await PurchaseService.restorePurchases();
                  if (widget.isParentMounted()) {
                    await widget.onRestoreComplete(restoredPro);
                  }
                },
                child: const Text(
                  'Restore purchases',
                  style: TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  await launchUrl(
                    Uri.parse('https://paprclip.app/terms'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text(
                  'Terms of Use',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
                ),
              ),
              const Text(
                ' · ',
                style: TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
              ),
              GestureDetector(
                onTap: () async {
                  await launchUrl(
                    Uri.parse('https://paprclip.app/privacy'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

void showRentlogProUpgradeBottomSheet(
  BuildContext context, {
    required bool Function() isParentMounted,
    required Color ctaColor,
    required Future<void> Function() onUnlocked,
    required Future<void> Function(bool restoredPro) onRestoreComplete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => RentlogProPlanSheet(
        isParentMounted: isParentMounted,
        ctaColor: ctaColor,
        onUnlocked: onUnlocked,
        onRestoreComplete: onRestoreComplete,
      ),
    );
  }
