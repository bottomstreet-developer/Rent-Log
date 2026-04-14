import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:rentlog/main.dart';
import '../services/database_helper.dart';
import '../utils/app_feedback.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final MaintenanceIssue? issue;
  const AddMaintenanceScreen({super.key, this.issue});

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final title = TextEditingController();
  final notes = TextEditingController();
  DateTime reported = DateTime.now();
  String status = 'open';
  List<String> _imagePaths = [];
  bool _showTitleError = false;

  @override
  void initState() {
    super.initState();
    final issue = widget.issue;
    if (issue != null) {
      title.text = issue.title;
      notes.text = issue.notes;
      reported = DateTime.tryParse(issue.reportedDate) ?? reported;
      status = issue.status;
      _imagePaths = issue.photosPaths.isEmpty
          ? <String>[]
          : issue.photosPaths
                .split(',')
                .where((p) => p.trim().isNotEmpty)
                .toList();
    }
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      setState(() => _showTitleError = true);
      return;
    }

    final lease = await DatabaseHelper.instance.getLatestLease();
    if (lease == null) return;
    final pathsString = _imagePaths.join(',');
    if (widget.issue != null) {
      await DatabaseHelper.instance.updateIssue(
        MaintenanceIssue(
          id: widget.issue!.id,
          leaseId: widget.issue!.leaseId,
          title: title.text.trim(),
          description: widget.issue!.description,
          reportedDate: reported.toIso8601String(),
          status: status,
          photosPaths: pathsString,
          notes: notes.text.trim(),
          createdAt: widget.issue!.createdAt,
        ),
      );
    } else {
      await DatabaseHelper.instance.insertIssue(
        MaintenanceIssue(
          leaseId: lease.id!,
          title: title.text.trim(),
          description: '',
          reportedDate: reported.toIso8601String(),
          status: status,
          photosPaths: pathsString,
          notes: notes.text.trim(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_imagePaths.length >= 5) return;
    try {
      suppressLock = true;
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _imagePaths.add(picked.path));
    } catch (_) {
      showAppSnackBar('Could not open camera/gallery. Please try again.');
    } finally {
      suppressLock = false;
    }
  }

  Future<void> _pickFromCamera() => _pickPhoto(ImageSource.camera);

  Future<void> _pickFromGallery() => _pickPhoto(ImageSource.gallery);

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

  String _statusLabel(String value) {
    switch (value) {
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'open':
      default:
        return 'Open';
    }
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    DateTime tempDate = reported;
    int selectedDay = reported.day;
    int selectedMonth = reported.month;
    int selectedYear = reported.year;

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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                    const Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => reported = tempDate);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
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
                              tempDate = DateTime(
                                selectedYear,
                                selectedMonth,
                                selectedDay,
                              );
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
                              tempDate = DateTime(
                                selectedYear,
                                selectedMonth,
                                selectedDay,
                              );
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
                              tempDate = DateTime(
                                selectedYear,
                                selectedMonth,
                                selectedDay,
                              );
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
            ],
          ),
        );
      },
    );

    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
  }

  void _showStatusPicker() {
    final options = ['Open', 'In Progress', 'Resolved'];
    final selected = _statusLabel(status);
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
              'Status',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (option) => GestureDetector(
                onTap: () {
                  setState(() {
                    if (option == 'Open') status = 'open';
                    if (option == 'In Progress') status = 'in_progress';
                    if (option == 'Resolved') status = 'resolved';
                  });
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
                        option,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selected == option
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (selected == option)
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

  @override
  Widget build(BuildContext context) {
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
                        'Add Issue',
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
                TextField(
                  controller: title,
                  onChanged: (_) {
                    if (_showTitleError && title.text.trim().isNotEmpty) {
                      setState(() => _showTitleError = false);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                if (_showTitleError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Please enter a title',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                              'Date Reported',
                              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('d MMM yyyy').format(reported),
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
                  onTap: _showStatusPicker,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _statusLabel(status),
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
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes',
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
