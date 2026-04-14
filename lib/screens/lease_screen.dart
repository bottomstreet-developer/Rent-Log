import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/database_helper.dart';
import '../services/purchase_service.dart';
import 'paywall_screen.dart';

class LeaseScreen extends StatefulWidget {
  const LeaseScreen({super.key, this.lease});
  final Lease? lease;

  @override
  State<LeaseScreen> createState() => _LeaseScreenState();
}

class _LeaseScreenState extends State<LeaseScreen> {
  final _form = GlobalKey<FormState>();
  final propertyName = TextEditingController();
  final address = TextEditingController();
  final landlordName = TextEditingController();
  final landlordContact = TextEditingController();
  final monthlyRent = TextEditingController();
  final depositAmount = TextEditingController();
  final notes = TextEditingController();
  int _noticePeriodDays = 30;
  DateTime start = DateTime.now();
  DateTime end = DateTime.now().add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    if (widget.lease != null) {
      final lease = widget.lease!;
      propertyName.text = lease.propertyName;
      address.text = lease.address;
      landlordName.text = lease.landlordName;
      landlordContact.text = lease.landlordContact;
      monthlyRent.text = lease.monthlyRent.toString();
      depositAmount.text = lease.depositAmount.toString();
      _noticePeriodDays = lease.noticePeriodDays;
      start = DateTime.parse(lease.leaseStartDate);
      end = DateTime.parse(lease.leaseEndDate);
      notes.text = lease.notes;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.lease == null) {
      final leases = await DatabaseHelper.instance.getLeases();
      final pro = await PurchaseService.isProUser();
      if (leases.isNotEmpty && !pro) {
        if (!mounted) return;
        final unlocked = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
        if (unlocked != true) return;
      }
    }
    final lease = Lease(
      id: widget.lease?.id,
      propertyName: propertyName.text.trim(),
      address: address.text.trim(),
      landlordName: landlordName.text.trim(),
      landlordContact: landlordContact.text.trim(),
      monthlyRent: double.tryParse(monthlyRent.text) ?? 0,
      depositAmount: double.tryParse(depositAmount.text) ?? 0,
      leaseStartDate: start.toIso8601String(),
      leaseEndDate: end.toIso8601String(),
      noticePeriodDays: _noticePeriodDays,
      notes: notes.text.trim(),
      createdAt: widget.lease?.createdAt ?? DateTime.now().toIso8601String(),
    );
    if (widget.lease == null) {
      await DatabaseHelper.instance.insertLease(lease);
    } else {
      await DatabaseHelper.instance.updateLease(lease);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _confirmDeleteLease() async {
    final leaseId = widget.lease?.id;
    if (leaseId == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.delete_outline,
              size: 32,
              color: Color(0xFFFF4757),
            ),
            const SizedBox(height: 12),
            const Text(
              'Delete Lease?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will permanently delete this lease and all associated payments, maintenance issues, and rent increases. This cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8A8A8A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4757),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete Lease'),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8A8A8A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteLeaseAndAssociatedRecords(leaseId);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RentLogShell()),
      (route) => false,
    );
  }

  void _showNoticePeriodPicker() {
    final options = [7, 14, 21, 30, 45, 60, 90];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notice Period',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How many days notice before leaving',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (days) => GestureDetector(
                onTap: () {
                  setState(() => _noticePeriodDays = days);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0F1F3)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$days days',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _noticePeriodDays == days
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_noticePeriodDays == days)
                        const Icon(
                          Icons.check,
                          size: 18,
                          color: Color(0xFF00C48C),
                        ),
                    ],
                  ),
                ),
              ),
            ).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? start : end;
    int selectedDay = initial.day;
    int selectedMonth = initial.month;
    int selectedYear = initial.year;

    final startYear = isStart ? now.year - 30 : now.year - 5;
    final yearCount = isStart ? 41 : 31;

    final FixedExtentScrollController dayController =
        FixedExtentScrollController(initialItem: selectedDay - 1);
    final FixedExtentScrollController monthController =
        FixedExtentScrollController(initialItem: selectedMonth - 1);
    final FixedExtentScrollController yearController =
        FixedExtentScrollController(initialItem: selectedYear - startYear);

    final months = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 320,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isStart ? 'Lease Start Date' : 'Lease End Date',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: ListWheelScrollView.useDelegate(
                            controller: dayController,
                            itemExtent: 44,
                            perspective: 0.003,
                            diameterRatio: 1.8,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) {
                              HapticFeedback.selectionClick();
                              selectedDay = i + 1;
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 31,
                              builder: (context, i) => Center(
                                child: Text(
                                  '${i + 1}'.padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: ListWheelScrollView.useDelegate(
                            controller: monthController,
                            itemExtent: 44,
                            perspective: 0.003,
                            diameterRatio: 1.8,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) {
                              HapticFeedback.selectionClick();
                              selectedMonth = i + 1;
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (context, i) => Center(
                                child: Text(
                                  months[i],
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: ListWheelScrollView.useDelegate(
                            controller: yearController,
                            itemExtent: 44,
                            perspective: 0.003,
                            diameterRatio: 1.8,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) {
                              HapticFeedback.selectionClick();
                              selectedYear = startYear + i;
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: yearCount,
                              builder: (context, i) => Center(
                                child: Text(
                                  '${startYear + i}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    try {
                      final picked = DateTime(
                        selectedYear,
                        selectedMonth,
                        selectedDay,
                      );
                      Navigator.pop(context);
                      if (!mounted) return;
                      setState(() => isStart ? start = picked : end = picked);
                    } catch (_) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
  }

  void _showDebugFillOptions() {
    final options = [
      {
        'label': 'NYC Studio — Active',
        'propertyName': 'Studio NYC',
        'address': '245 E 54th St, New York, NY 10022',
        'landlordName': 'Michael Cohen',
        'landlordContact': 'mcohen@realty.com',
        'rent': '2800',
        'deposit': '5600',
        'noticePeriod': 30,
        'startDate': DateTime(2024, 1, 1),
        'endDate': DateTime(2026, 12, 31),
        'notes': 'Floor 8, Unit 8C. Super is Carlos.',
      },
      {
        'label': 'LA Apartment — Expiring Soon',
        'propertyName': 'Silver Lake Apt',
        'address': '3801 Sunset Blvd, Los Angeles, CA 90026',
        'landlordName': 'Sarah Park',
        'landlordContact': '+1 323 555 0192',
        'rent': '2200',
        'deposit': '4400',
        'noticePeriod': 60,
        'startDate': DateTime(2023, 6, 1),
        'endDate': DateTime(
          DateTime.now().year,
          DateTime.now().month + 2,
          1,
        ),
        'notes': 'Pet friendly. Parking spot #12.',
      },
      {
        'label': 'Chicago Condo — Long Term',
        'propertyName': 'Lincoln Park Condo',
        'address': '2400 N Lakeview Ave, Chicago, IL 60614',
        'landlordName': 'James Realty LLC',
        'landlordContact': 'leasing@jamesrealty.com',
        'rent': '1850',
        'deposit': '3700',
        'noticePeriod': 30,
        'startDate': DateTime(2022, 3, 1),
        'endDate': DateTime(2027, 2, 28),
        'notes': 'Utilities included. Gym access on 2nd floor.',
      },
      {
        'label': 'Austin House — New Lease',
        'propertyName': 'East Austin House',
        'address': '1204 E 6th St, Austin, TX 78702',
        'landlordName': 'Texas Properties Inc',
        'landlordContact': '+1 512 555 0148',
        'rent': '3200',
        'deposit': '6400',
        'noticePeriod': 60,
        'startDate': DateTime.now(),
        'endDate': DateTime(
          DateTime.now().year + 1,
          DateTime.now().month,
          DateTime.now().day,
        ),
        'notes': 'Backyard access. No smoking.',
      },
      {
        'label': 'London Flat — GBP',
        'propertyName': 'Shoreditch Flat',
        'address': '42 Brick Lane, London E1 6RF',
        'landlordName': 'Eastside Lettings',
        'landlordContact': 'info@eastsidelettings.co.uk',
        'rent': '1950',
        'deposit': '3900',
        'noticePeriod': 30,
        'startDate': DateTime(2025, 9, 1),
        'endDate': DateTime(2026, 8, 31),
        'notes': 'Council tax band C. Furnished.',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug: Auto-fill Lease',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a test scenario',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (option) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _fillWithOption(option);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0F1F3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['label']! as String,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${option['rent']}/mo · ${option['address']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A8A8A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFFCCCCCC),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fillWithOption(Map<String, dynamic> option) {
    setState(() {
      propertyName.text = option['propertyName'] as String;
      address.text = option['address'] as String;
      landlordName.text = option['landlordName'] as String;
      landlordContact.text = option['landlordContact'] as String;
      monthlyRent.text = option['rent'] as String;
      depositAmount.text = option['deposit'] as String;
      _noticePeriodDays = option['noticePeriod'] as int;
      start = option['startDate'] as DateTime;
      end = option['endDate'] as DateTime;
      notes.text = option['notes'] as String;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Lease Setup',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Form(
                key: _form,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    children: [
                      _field(
                        propertyName,
                        'Property Name',
                        hint: 'e.g. Downtown Apartment, Studio NYC',
                      ),
                      const SizedBox(height: 16),
                      _field(
                        address,
                        'Address',
                        hint: 'Street, City, State, ZIP',
                      ),
                      const SizedBox(height: 16),
                      _field(
                        landlordName,
                        'Landlord Name',
                        hint: 'Landlord name (optional)',
                        required: false,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        landlordContact,
                        'Landlord Contact',
                        hint: 'Phone or email (optional)',
                        required: false,
                      ),
                      const SizedBox(height: 16),
                      _moneyField(
                        monthlyRent,
                        fieldLabel: 'Monthly Rent',
                        hint: '0.00',
                      ),
                      const SizedBox(height: 16),
                      _moneyField(
                        depositAmount,
                        fieldLabel: 'Security Deposit',
                        hint: '0.00',
                      ),
                      const SizedBox(height: 16),
                      _noticePeriodField(),
                      const SizedBox(height: 16),
                      _dateField(
                        label: 'Lease Start Date',
                        value: DateFormat('d MMM yyyy').format(start),
                        onTap: () => _pickDate(true),
                      ),
                      const SizedBox(height: 16),
                      _dateField(
                        label: 'Lease End Date',
                        value: DateFormat('d MMM yyyy').format(end),
                        onTap: () => _pickDate(false),
                      ),
                      const SizedBox(height: 16),
                      _field(
                        notes,
                        'Notes',
                        hint: 'Any notes (optional)',
                        lines: 3,
                        required: false,
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text('Save Lease'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF8A8A8A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.lease != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: GestureDetector(
                          onTap: _confirmDeleteLease,
                          child: const Center(
                            child: Text(
                              'Delete Lease',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFFFF4757),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: kDebugMode
            ? FloatingActionButton.small(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                onPressed: _showDebugFillOptions,
                child: const Icon(Icons.bug_report_outlined, size: 18),
              )
            : null,
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    TextInputType? keyboard,
    int lines = 1,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A8A8A),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          autofocus: false,
          enabled: true,
          keyboardType: keyboard,
          minLines: lines > 1 ? lines : null,
          maxLines: lines,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E6EA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E6EA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8A8A8A),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _moneyField(
    TextEditingController controller, {
    required String fieldLabel,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fieldLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A8A8A),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          autofocus: false,
          enabled: true,
          keyboardType: TextInputType.number,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 15),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Text(
                '\$',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E6EA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E6EA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1A1A1A),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _noticePeriodField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notice Period',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A8A8A),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showNoticePeriodPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E6EA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_noticePeriodDays days',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFF8A8A8A),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A8A8A),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E6EA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF8A8A8A),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
