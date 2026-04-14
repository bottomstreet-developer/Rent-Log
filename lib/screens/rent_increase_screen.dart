import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../widgets/app_chrome.dart';

class RentIncreaseScreen extends StatefulWidget {
  const RentIncreaseScreen({super.key});

  @override
  State<RentIncreaseScreen> createState() => _RentIncreaseScreenState();
}

class _RentIncreaseScreenState extends State<RentIncreaseScreen> {
  List<RentIncrease> increases = [];
  Lease? lease;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await DatabaseHelper.instance.getLatestLease();
    final list = l == null
        ? <RentIncrease>[]
        : await DatabaseHelper.instance.getIncreases(l.id!);
    if (!mounted) return;
    setState(() {
      lease = l;
      increases = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final original = increases.isEmpty
        ? (lease?.monthlyRent ?? 0)
        : increases.last.oldAmount;
    final current = increases.isEmpty
        ? (lease?.monthlyRent ?? 0)
        : increases.first.newAmount;
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
                    'Rent Increase Tracker',
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: premiumCardDecoration(),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Current vs original'),
                    subtitle: Text(
                      '\$${current.toStringAsFixed(2)} vs \$${original.toStringAsFixed(2)}',
                    ),
                  ),
                ),
                if (increases.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No rent changes recorded yet'),
                  ),
                ...increases.map((r) {
                  final pct = r.oldAmount == 0
                      ? 0
                      : ((r.newAmount - r.oldAmount) / r.oldAmount) * 100;
                  final d = DateTime.tryParse(r.effectiveDate);
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: premiumCardDecoration(),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '\$${r.oldAmount.toStringAsFixed(2)} -> \$${r.newAmount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(
                        '${d == null ? r.effectiveDate : DateFormat('d MMM yyyy').format(d)} • ${pct.toStringAsFixed(1)}% increase',
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (lease == null) return;
          final oldCtrl = TextEditingController(
            text:
                (increases.isEmpty
                        ? lease!.monthlyRent
                        : increases.first.newAmount)
                    .toStringAsFixed(2),
          );
          final newCtrl = TextEditingController();
          DateTime effective = DateTime.now();
          final save =
              await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Add increase'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: oldCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Old amount',
                        ),
                      ),
                      TextField(
                        controller: newCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'New amount',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!save) return;
          await DatabaseHelper.instance.insertIncrease(
            RentIncrease(
              leaseId: lease!.id!,
              oldAmount: double.tryParse(oldCtrl.text) ?? 0,
              newAmount: double.tryParse(newCtrl.text) ?? 0,
              effectiveDate: effective.toIso8601String(),
              notes: '',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
