import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/database_helper.dart';
import '../services/purchase_service.dart';
import '../utils/currency_notifier.dart';
import '../widgets/app_chrome.dart';
import '../widgets/rentlog_pro_plan_sheet.dart';
import 'lease_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  Lease? _currentLease;
  List<Lease> _allLeases = [];
  List<RentPayment> payments = [];
  int _selectedLeaseIndex = 0;

  String _formatPaymentMethod(String raw) {
    return raw
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    rentLogTabNotifier.addListener(_onRentLogTabNotifier);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      rentLogRouteObserver.unsubscribe(this);
      rentLogRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    rentLogRouteObserver.unsubscribe(this);
    rentLogTabNotifier.removeListener(_onRentLogTabNotifier);
    super.dispose();
  }

  void _onRentLogTabNotifier() {
    if (rentLogTabNotifier.value == 0 && mounted) {
      _load();
    }
  }

  @override
  void didPopNext() {
    if (rentLogTabNotifier.value == 0 && mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    final leases = await DatabaseHelper.instance.getLeases();
    final selectedIndex = leases.isEmpty
        ? 0
        : (_selectedLeaseIndex < leases.length ? _selectedLeaseIndex : 0);
    final selectedLease = leases.isEmpty ? null : leases[selectedIndex];
    final p = selectedLease == null
        ? <RentPayment>[]
        : await DatabaseHelper.instance.getPayments(selectedLease.id!);
    p.sort(
      (a, b) =>
          (DateTime.tryParse(b.paymentDate) ?? DateTime(1970)).compareTo(
            DateTime.tryParse(a.paymentDate) ?? DateTime(1970),
          ),
    );
    if (!mounted) return;
    setState(() {
      _allLeases = leases;
      _selectedLeaseIndex = selectedIndex;
      _currentLease = selectedLease;
      payments = p.take(3).toList();
    });
  }

  Future<void> _loadPaymentsForLease(int leaseId) async {
    final p = await DatabaseHelper.instance.getPayments(leaseId);
    p.sort(
      (a, b) =>
          (DateTime.tryParse(b.paymentDate) ?? DateTime(1970)).compareTo(
            DateTime.tryParse(a.paymentDate) ?? DateTime(1970),
          ),
    );
    if (!mounted) return;
    setState(() => payments = p.take(3).toList());
  }

  Future<void> _onAddProperty() async {
    final isProUser = await PurchaseService.isProUser();
    if (!mounted) return;
    if (isProUser) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeaseScreen()),
      ).then((_) => _load());
    } else {
      _showProUpgradeSheet();
    }
  }

  void _showProUpgradeSheet() {
    showRentlogProUpgradeBottomSheet(
      context,
      isParentMounted: () => mounted,
      ctaColor: const Color(0xFF00C48C),
      onUnlocked: () async {
        if (!mounted) return;
        await _load();
      },
      onRestoreComplete: (_) async {
        if (mounted) await _load();
      },
    );
  }

  void _showPropertySwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: double.infinity,
              child: Text(
                'Your Properties',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ..._allLeases.asMap().entries.map((entry) {
              final index = entry.key;
              final lease = entry.value;
              final isSelected = index == _selectedLeaseIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedLeaseIndex = index;
                    _currentLease = lease;
                  });
                  Navigator.pop(context);
                  _loadPaymentsForLease(lease.id!);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0F1F3)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lease.propertyName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${currencyNotifier.value}${NumberFormat('#,###').format(lease.monthlyRent)}/mo · ${lease.address.isEmpty ? 'No address' : lease.address}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8A8A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: Color(0xFF00C48C),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _onAddProperty();
              },
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 20,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add another property',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoFillDebugData() async {
    final leaseId = await DatabaseHelper.instance.insertLease(
      Lease(
        propertyName: 'Test Apartment',
        address: '123 Main Street, New York, NY 10001',
        landlordName: 'John Smith',
        landlordContact: 'john@example.com',
        monthlyRent: 2000,
        depositAmount: 4000,
        leaseStartDate: DateTime.parse('2024-01-01').toIso8601String(),
        leaseEndDate: DateTime.parse('2025-12-31').toIso8601String(),
        noticePeriodDays: 30,
        notes: 'Test lease for development',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    final paymentDates = [
      DateTime.parse('2025-01-01'),
      DateTime.parse('2025-02-01'),
      DateTime.parse('2025-03-01'),
    ];
    for (final date in paymentDates) {
      await DatabaseHelper.instance.insertPayment(
        RentPayment(
          leaseId: leaseId,
          amount: 2000,
          paymentDate: date.toIso8601String(),
          paymentMethod: 'bank_transfer',
          receiptImagePath: '',
          notes: '',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    await DatabaseHelper.instance.insertIssue(
      MaintenanceIssue(
        leaseId: leaseId,
        title: 'Leaking tap',
        description: 'Kitchen tap leaking since Jan 2025',
        reportedDate: DateTime.parse('2025-01-15').toIso8601String(),
        status: 'open',
        photosPaths: '',
        notes: '',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    await DatabaseHelper.instance.insertIncrease(
      RentIncrease(
        leaseId: leaseId,
        oldAmount: 1800,
        newAmount: 2000,
        effectiveDate: DateTime.parse('2024-01-01').toIso8601String(),
        notes: 'Annual increase',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Debug test data added')));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, currencySymbol, _) {
        final money = NumberFormat.currency(
          symbol: currencySymbol,
          decimalDigits: 0,
        );
        if (_currentLease == null) {
          return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Text(
                    'Rent Log',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: Color(0xFF8A8A8A),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No lease added yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your lease details to start tracking rent payments and history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8A8A8A),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/lease',
                          ).then((_) => _load()),
                          child: const Text('Add First Lease'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    final lease = _currentLease!;
    final end = DateTime.tryParse(lease.leaseEndDate) ?? DateTime.now();
    final days = end.difference(DateTime.now()).inDays;
    final statusBg = days < 0
        ? const Color(0xFFFFF0F1)
        : days < 60
            ? const Color(0xFFFFFBF0)
            : const Color(0xFFF0FBF7);
    final statusFg = days < 0
        ? const Color(0xFFFF4757)
        : days < 60
            ? const Color(0xFFFFB020)
            : const Color(0xFF00C48C);
    final statusLabel = days < 0 ? 'Expired' : '$days days left';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: _onAddProperty,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _showPropertySwitcher,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentLease?.propertyName ?? 'My Property',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A8A8A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF8A8A8A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: premiumCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTHLY RENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Color(0xFF8A8A8A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money.format(lease.monthlyRent),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'per month',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusFg, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
                  if (days < 60)
                    Container(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF0),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(
                          left: BorderSide(color: Color(0xFFFFB020), width: 3),
                        ),
                      ),
                      child: const Text(
                        'Lease expires in under 60 days',
                        style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (days < 60) const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8ECF0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'LEASE DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8A8A8A),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LeaseScreen(
                                      lease: _currentLease,
                                    ),
                                  ),
                                ).then((_) => _load()),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF00C48C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE8ECF0)),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _leaseDetailRow(
                                      'Start',
                                      DateFormat('d MMM yyyy').format(
                                        DateTime.parse(lease.leaseStartDate),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _leaseDetailRow(
                                      'End',
                                      DateFormat('d MMM yyyy').format(
                                        DateTime.parse(lease.leaseEndDate),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _leaseDetailRow(
                                      'Deposit',
                                      '$currencySymbol${NumberFormat('#,###').format(lease.depositAmount)}',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _leaseDetailRow(
                                      'Notice Period',
                                      '${lease.noticePeriodDays} days',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RECENT PAYMENTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                      TextButton(
                        onPressed: () => rentLogTabNotifier.value = 1,
                        child: const Text(
                          'See All',
                          style: TextStyle(color: Color(0xFF00C48C), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (payments.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.credit_card_outlined,
                            size: 32,
                            color: Color(0xFFB0B0B0),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No payments logged yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8A8A8A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Head to Payments tab to log your first payment',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFB0B0B0),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: premiumCardDecoration(),
                      child: Column(
                        children: [
                          for (var i = 0; i < payments.length; i++) ...[
                            ListTile(
                              title: Text(
                                DateFormat('d MMM yyyy').format(
                                  DateTime.tryParse(payments[i].paymentDate) ?? DateTime.now(),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              subtitle: Text(
                                _formatPaymentMethod(payments[i].paymentMethod),
                                style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12),
                              ),
                              trailing: Text(
                                money.format(payments[i].amount),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            if (i < payments.length - 1)
                              const Divider(
                                height: 1,
                                color: Color(0xFFE8ECF0),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: premiumCardDecoration(),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Icon(icon, color: Color(0xFF8A8A8A), size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leaseDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8A8A8A),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _debugFab() {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      onPressed: _autoFillDebugData,
      child: const Icon(Icons.add),
    );
  }
}

