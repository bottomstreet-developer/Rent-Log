import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_maintenance_screen.dart';
import '../services/database_helper.dart';
import '../utils/app_dialogs.dart';
import '../widgets/app_chrome.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String _selectedFilter = 'All';
  List<MaintenanceIssue> issues = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? status;
    switch (_selectedFilter) {
      case 'Open':
        status = 'open';
        break;
      case 'In Progress':
        status = 'in_progress';
        break;
      case 'Resolved':
        status = 'resolved';
        break;
      case 'All':
      default:
        status = null;
    }
    final lease = await DatabaseHelper.instance.getLatestLease();
    final list = lease == null
        ? <MaintenanceIssue>[]
        : await DatabaseHelper.instance.getIssues(lease.id!, status: status);
    if (!mounted) return;
    setState(() => issues = list);
  }

  Future<void> _showIssueDetails(MaintenanceIssue issue) async {
    final imagePaths = issue.photosPaths
        .split(',')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    await showModalBottomSheet(
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
            Text(
              issue.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (issue.description.isNotEmpty)
              Text(
                issue.description,
                style: const TextStyle(
                  color: Color(0xFF8A8A8A),
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              DateFormat('d MMM yyyy').format(
                DateTime.tryParse(issue.reportedDate) ?? DateTime.now(),
              ),
              style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 13),
            ),
            if (issue.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                issue.notes,
                style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 13),
              ),
            ],
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagePaths.length,
                  itemBuilder: (context, index) => Padding(
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
            ],
            const SizedBox(height: 20),
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A8A8A),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: Row(
                children: const [
                  ('open', 'Open'),
                  ('in_progress', 'In Progress'),
                  ('resolved', 'Resolved'),
                ].asMap().entries.map((entry) {
                  final key = entry.value.$1;
                  final label = entry.value.$2;
                  final selected = issue.status == key;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: entry.key < 2 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () async {
                          if (selected) {
                            Navigator.pop(context);
                            return;
                          }
                          final updated = MaintenanceIssue(
                            id: issue.id,
                            leaseId: issue.leaseId,
                            title: issue.title,
                            description: issue.description,
                            reportedDate: issue.reportedDate,
                            status: key,
                            photosPaths: issue.photosPaths,
                            notes: issue.notes,
                            createdAt: issue.createdAt,
                          );
                          await DatabaseHelper.instance.updateIssue(updated);
                          if (context.mounted) Navigator.pop(context);
                          await _load();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF1A1A1A) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: selected
                                ? null
                                : Border.all(color: const Color(0xFF1A1A1A)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF1A1A1A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final updated = await Navigator.push(
                  this.context,
                  MaterialPageRoute(
                    builder: (_) => AddMaintenanceScreen(issue: issue),
                  ),
                );
                if (updated == true) {
                  _load();
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
                    'Edit Issue',
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
              onTap: () async {
                final shouldDelete = await showConfirmDialog(
                  context,
                  title: 'Delete Issue?',
                  content:
                      'Are you sure you want to delete this maintenance issue?',
                  confirmLabel: 'Delete',
                );
                if (!shouldDelete || issue.id == null) return;
                await DatabaseHelper.instance.deleteIssue(issue.id!);
                if (context.mounted) Navigator.pop(context);
                await _load();
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
                    'Delete Issue',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const AppHeader(title: 'Maintenance'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['All', 'Open', 'In Progress', 'Resolved'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    _load();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF0F1F3),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF8A8A8A),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: issues.isEmpty
                ? const Center(child: Text('No maintenance issues yet'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: issues.length,
                    itemBuilder: (_, i) {
                      final issue = issues[i];
                      final d = DateTime.tryParse(issue.reportedDate);
                      return GestureDetector(
                        onTap: () => _showIssueDetails(issue),
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
                                      issue.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      d == null
                                          ? issue.reportedDate
                                          : DateFormat('d MMM yyyy').format(d),
                                      style: const TextStyle(
                                        color: Color(0xFF8A8A8A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _statusChip(issue.status),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.pushNamed(
          context,
          '/add_maintenance',
        ).then((_) => _load()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = const Color(0xFFFF4757);
    Color bg = const Color(0xFFFFF0F1);
    String label = 'Open';
    if (status == 'in_progress') {
      color = const Color(0xFFFFB020);
      bg = const Color(0xFFFFFBF0);
      label = 'In Progress';
    }
    if (status == 'resolved') {
      color = const Color(0xFF00C48C);
      bg = const Color(0xFFF0FBF7);
      label = 'Resolved';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

}
