import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'add_payment_screen.dart';
import '../services/database_helper.dart';
import '../services/pdf_service.dart';
import '../services/purchase_service.dart';
import '../utils/app_dialogs.dart';
import '../utils/currency_notifier.dart';
import '../widgets/app_chrome.dart';
import '../widgets/rentlog_pro_plan_sheet.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Lease> leases = [];
  final Map<int, List<RentPayment>> paymentsByLease = {};

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
    _load();
  }

  Future<void> _load() async {
    final leaseList = await DatabaseHelper.instance.getLeases();
    final grouped = <int, List<RentPayment>>{};
    for (final lease in leaseList) {
      final id = lease.id;
      if (id == null) continue;
      grouped[id] = await DatabaseHelper.instance.getPayments(id);
    }
    if (!mounted) return;
    setState(() {
      leases = leaseList;
      paymentsByLease
        ..clear()
        ..addAll(grouped);
    });
  }

  Future<void> _loadPayments() async {
    await _load();
  }

  Future<void> _exportPaymentHistoryPdf() async {
    if (leases.isEmpty) return;
    final remotePro = await PurchaseService.isProUser();
    if (!mounted) return;
    final isPro = remotePro || PurchaseService.isDebugProEnabled;
    if (!isPro) {
      showRentlogProUpgradeBottomSheet(
        context,
        isParentMounted: () => mounted,
        ctaColor: const Color(0xFF00C48C),
        onUnlocked: () async {
          if (mounted) await _loadPayments();
        },
        onRestoreComplete: (_) async {
          if (mounted) await _loadPayments();
        },
      );
      return;
    }
    final exportableLeases = leases.where((l) => l.id != null).toList();
    if (exportableLeases.isEmpty) return;
    if (exportableLeases.length == 1) {
      await PdfService.exportPaymentHistory(exportableLeases.first.id!);
      return;
    }
    final pickedId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(sheetContext).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            ...exportableLeases.map(
              (lease) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(sheetContext, lease.id!),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0F1F3)),
                    ),
                  ),
                  child: Text(
                    lease.propertyName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || pickedId == null) return;
    await PdfService.exportPaymentHistory(pickedId);
  }

  void _showPaymentDetail(RentPayment payment, String currencySymbol) {
    final imagePaths = payment.receiptImagePath.isNotEmpty
        ? payment.receiptImagePath
              .split(',')
              .where((p) => p.isNotEmpty)
              .toList()
        : <String>[];

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _detailRow(
              'Amount',
              '$currencySymbol${NumberFormat('#,##0.00').format(payment.amount)}',
            ),
            _detailRow(
              'Date',
              DateFormat('d MMM yyyy').format(DateTime.parse(payment.paymentDate)),
            ),
            _detailRow('Method', _formatPaymentMethod(payment.paymentMethod)),
            if (payment.notes.isNotEmpty) _detailRow('Notes', payment.notes),
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Receipts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A8A8A),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagePaths.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FullScreenImageViewer(
                            imagePaths: imagePaths,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < imagePaths.length - 1 ? 8 : 0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(imagePaths[index]),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final updated = await Navigator.push(
                  this.context,
                  MaterialPageRoute(
                    builder: (_) => AddPaymentScreen(payment: payment),
                  ),
                );
                if (updated == true) {
                  _loadPayments();
                }
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E6EA)),
                ),
                child: const Center(
                  child: Text(
                    'Edit Payment',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _deletePayment(payment);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Delete Payment',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8A8A8A)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePayment(RentPayment payment) async {
    final shouldDelete = await showConfirmDialog(
      context,
      title: 'Delete Payment?',
      content:
          'Are you sure you want to delete this payment? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!shouldDelete) return;
    await DatabaseHelper.instance.deletePayment(payment.id!);
    _loadPayments();
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
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle.dark,
                      child: Container(
                        color: Colors.white,
                        width: double.infinity,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 8, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Payments',
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1A1A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _exportPaymentHistoryPdf,
                                  child: const Text(
                                    'Export PDF',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: leases.isEmpty
                          ? const Center(child: Text('No lease found yet'))
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                ...leases.map((lease) {
                                  final leasePayments =
                                      paymentsByLease[lease.id ?? -1] ?? <RentPayment>[];
                                  final totalPaid = leasePayments.fold<double>(
                                    0,
                                    (sum, p) => sum + p.amount,
                                  );
                                  final lastPayment = leasePayments.isNotEmpty
                                      ? leasePayments.first
                                      : null;
                                  final lastDate = lastPayment == null
                                      ? '-'
                                      : DateFormat('d MMM yyyy').format(
                                          DateTime.parse(lastPayment.paymentDate),
                                        );
                                  final lastAmount = lastPayment == null
                                      ? '-'
                                      : money.format(lastPayment.amount);

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lease.address,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: premiumCardDecoration(),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Last Payment',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF8A8A8A),
                                                  ),
                                                ),
                                                Text(
                                                  '$lastDate • $lastAmount',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1A1A1A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Total Paid',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF8A8A8A),
                                                  ),
                                                ),
                                                Text(
                                                  money.format(totalPaid),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1A1A1A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (leasePayments.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: Text('No payments logged yet'),
                                        )
                                      else
                                        ...leasePayments.map(
                                          (p) => _tileSimple(p, currencySymbol),
                                        ),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                }),
                              ],
                            ),
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    onPressed: () => Navigator.pushNamed(context, '/add_payment')
                        .then((_) => _load()),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _tileSimple(RentPayment p, String currencySymbol) {
    final money = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    final d = DateTime.tryParse(p.paymentDate);
    final formattedDate = d == null
        ? p.paymentDate
        : DateFormat('d MMM yyyy').format(d);
    return GestureDetector(
      onTap: () => _showPaymentDetail(p, currencySymbol),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: premiumCardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatPaymentMethod(p.paymentMethod),
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              money.format(p.amount),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  const _FullScreenImageViewer({
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => InteractiveViewer(
                child: Center(
                  child: Image.file(File(widget.imagePaths[index])),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
            if (widget.imagePaths.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.imagePaths.length,
                    (index) => Container(
                      width: index == _currentIndex ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
