import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:rentlog/main.dart';
import '../services/database_helper.dart';
import '../utils/currency_notifier.dart';
import '../utils/app_feedback.dart';

class AddPaymentScreen extends StatefulWidget {
  final RentPayment? payment;
  const AddPaymentScreen({super.key, this.payment});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final amount = TextEditingController();
  final notes = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedMethod = 'Cash';
  List<String> _imagePaths = [];
  bool _showAmountError = false;
  List<Lease> _leases = [];
  int? _selectedLeaseId;

  @override
  void initState() {
    super.initState();
    _loadLeases();
  }

  Future<void> _loadLeases() async {
    final leases = await DatabaseHelper.instance.getLeases();
    final latest = await DatabaseHelper.instance.getLatestLease();
    if (!mounted) return;
    setState(() {
      _leases = leases;
      if (latest?.id != null) {
        _selectedLeaseId = latest!.id;
      } else if (leases.length == 1) {
        _selectedLeaseId = leases.first.id;
      } else if (leases.isNotEmpty) {
        _selectedLeaseId = leases.first.id;
      }
      final existing = widget.payment;
      if (existing != null) {
        _selectedLeaseId = existing.leaseId;
        amount.text = existing.amount.toString();
        notes.text = existing.notes;
        _selectedDate = DateTime.tryParse(existing.paymentDate) ?? _selectedDate;
        _selectedMethod = _methodLabel(existing.paymentMethod);
        _imagePaths = existing.receiptImagePath.isEmpty
            ? <String>[]
            : existing.receiptImagePath
                  .split(',')
                  .where((p) => p.trim().isNotEmpty)
                  .toList();
      }
    });
  }

  String _selectedLeaseLabel() {
    for (final lease in _leases) {
      if (lease.id == _selectedLeaseId) {
        return lease.address.isEmpty ? lease.propertyName : lease.address;
      }
    }
    return '-';
  }

  Future<void> _save() async {
    final parsedAmount = double.tryParse(amount.text.trim()) ?? 0;
    if (parsedAmount <= 0) {
      setState(() => _showAmountError = true);
      return;
    }

    final leaseId = _selectedLeaseId ??
        (_leases.length == 1 ? _leases.first.id : null);
    if (leaseId == null) return;
    final pathsString = _imagePaths.join(',');
    if (widget.payment != null) {
      await DatabaseHelper.instance.updatePayment(
        RentPayment(
          id: widget.payment!.id,
          leaseId: leaseId,
          amount: parsedAmount,
          paymentDate: _selectedDate.toIso8601String(),
          paymentMethod: _methodCode(_selectedMethod),
          receiptImagePath: pathsString,
          notes: notes.text.trim(),
          createdAt: widget.payment!.createdAt,
        ),
      );
    } else {
      await DatabaseHelper.instance.insertPayment(
        RentPayment(
          leaseId: leaseId,
          amount: parsedAmount,
          paymentDate: _selectedDate.toIso8601String(),
          paymentMethod: _methodCode(_selectedMethod),
          receiptImagePath: pathsString,
          notes: notes.text.trim(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _methodCode(String selected) {
    switch (selected) {
      case 'Bank Transfer':
        return 'bank_transfer';
      case 'App':
        return 'app';
      case 'Cheque':
        return 'cheque';
      case 'Cash':
      default:
        return 'cash';
    }
  }

  String _methodLabel(String code) {
    switch (code) {
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'app':
        return 'App';
      case 'cheque':
        return 'Cheque';
      case 'cash':
      default:
        return 'Cash';
    }
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    int selectedDay = _selectedDate.day;
    int selectedMonth = _selectedDate.month;
    int selectedYear = _selectedDate.year;

    final FixedExtentScrollController dayController =
        FixedExtentScrollController(initialItem: selectedDay - 1);
    final FixedExtentScrollController monthController =
        FixedExtentScrollController(initialItem: selectedMonth - 1);
    final FixedExtentScrollController yearController =
        FixedExtentScrollController(initialItem: selectedYear - (now.year - 30));

    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Date',
                style: TextStyle(
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
                              selectedYear = (now.year - 30) + i;
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 31,
                              builder: (context, i) => Center(
                                child: Text(
                                  '${(now.year - 30) + i}',
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
                      final picked = DateTime(selectedYear, selectedMonth, selectedDay);
                      Navigator.pop(context);
                      if (!mounted) return;
                      setState(() => _selectedDate = picked);
                    } catch (_) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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

  void _showMethodPicker() {
    final methods = ['Cash', 'Bank Transfer', 'App', 'Cheque'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...methods.map(
              (method) => GestureDetector(
                onTap: () {
                  setState(() => _selectedMethod = method);
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
                        method,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedMethod == method
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_selectedMethod == method)
                        const Icon(Icons.check, size: 18, color: Color(0xFF00C48C)),
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

  void _showLeasePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ..._leases.map(
              (lease) => GestureDetector(
                onTap: () {
                  setState(() => _selectedLeaseId = lease.id);
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
                      Expanded(
                        child: Text(
                          lease.address.isEmpty ? lease.propertyName : lease.address,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selectedLeaseId == lease.id
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      if (_selectedLeaseId == lease.id)
                        const Icon(Icons.check, size: 18, color: Color(0xFF00C48C)),
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

  Future<void> _pickImage(ImageSource source) async {
    if (_imagePaths.length >= 5) return;
    try {
      suppressLock = true;
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _imagePaths.add(picked.path));
    } catch (_) {
      showAppSnackBar('Could not open camera/gallery. Please try again.');
    } finally {
      suppressLock = false;
    }
  }

  Future<void> _pickFromCamera() => _pickImage(ImageSource.camera);

  Future<void> _pickFromGallery() => _pickImage(ImageSource.gallery);

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewImageFullScreen(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          imagePaths: _imagePaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, currencySymbol, _) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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
                        'Add Payment',
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_leases.length > 1) ...[
                  GestureDetector(
                    onTap: _showLeasePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4E6EA)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Property',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A8A8A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedLeaseLabel(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
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
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_showAmountError) {
                      final parsed = double.tryParse(amount.text.trim()) ?? 0;
                      if (parsed > 0) {
                        setState(() => _showAmountError = false);
                      }
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Amount',
                    hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        currencySymbol,
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
                  ),
                ),
                if (_showAmountError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Please enter a valid amount',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _showDatePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE4E6EA)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A8A8A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('d MMM yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
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
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _showMethodPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE4E6EA)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Method',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A8A8A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedMethod,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickFromCamera,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE4E6EA)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                                color: Color(0xFF1A1A1A),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Camera',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE4E6EA)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 18,
                                color: Color(0xFF1A1A1A),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Gallery',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagePaths.length + (_imagePaths.length < 5 ? 1 : 0),
                      itemBuilder: (context, index) {
                        final isAddTile = index == _imagePaths.length;
                        final totalItems =
                            _imagePaths.length + (_imagePaths.length < 5 ? 1 : 0);
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < totalItems - 1 ? 8 : 0,
                          ),
                          child: isAddTile
                              ? GestureDetector(
                                  onTap: _showImageSourceSheet,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      color: const Color(0xFFF0F0F0),
                                      child: const Center(
                                        child: Icon(
                                          Icons.add,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () => _viewImageFullScreen(index),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          File(_imagePaths[index]),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => _imagePaths.removeAt(index),
                                          ),
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  if (_imagePaths.length < 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_imagePaths.length}/5 photos',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: notes,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
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
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _save,
                  child: const Text('Save'),
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
              ],
            ),
          ),
        ],
      ),
    );
      },
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
