import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentlog/services/backup_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../utils/app_dialogs.dart';
import '../utils/app_feedback.dart';
import '../widgets/rentlog_pro_plan_sheet.dart';
import '../utils/currency_notifier.dart';
import 'earn_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool rentReminder = false;
  int dueDay = 1;
  bool leaseReminder = false;
  int reminderDays = 60;
  String _appVersion = '-';
  String _currencySymbol = '\$';
  bool _appLockEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  Future<String?> _lastBackupDateFuture = BackupService.getLastBackupDate();
  late Future<bool> _proFuture;

  @override
  void initState() {
    super.initState();
    _proFuture = PurchaseService.isProUser();
    _load();
  }

  Future<void> _load() async {
    bool loadedRentReminder = false;
    int loadedDueDay = 1;
    bool loadedLeaseReminder = false;
    int loadedReminderDays = 60;
    String loadedVersion = '-';
    String loadedCurrency = '\$';
    bool loadedAppLockEnabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      loadedRentReminder = prefs.getBool('rentReminder') ?? false;
      loadedDueDay = prefs.getInt('dueDay') ?? 1;
      loadedLeaseReminder = prefs.getBool('leaseReminder') ?? false;
      loadedReminderDays = prefs.getInt('leaseReminderDays') ?? 60;
      loadedCurrency = prefs.getString('currency_symbol') ?? '\$';
      loadedAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    } catch (_) {}
    try {
      final info = await PackageInfo.fromPlatform();
      loadedVersion = info.version;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      rentReminder = loadedRentReminder;
      dueDay = loadedDueDay;
      leaseReminder = loadedLeaseReminder;
      reminderDays = loadedReminderDays;
      _appVersion = loadedVersion;
      _currencySymbol = loadedCurrency;
      _appLockEnabled = loadedAppLockEnabled;
    });
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rentReminder', rentReminder);
      await prefs.setInt('dueDay', dueDay);
      await prefs.setBool('leaseReminder', leaseReminder);
      await prefs.setInt('leaseReminderDays', reminderDays);
      await prefs.setString('currency_symbol', _currencySymbol);
      currencyNotifier.value = _currencySymbol;
      await prefs.setBool('app_lock_enabled', _appLockEnabled);
    } catch (_) {}
    await NotificationService.cancelAllReminders();
    if (rentReminder) {
      await NotificationService.scheduleMonthlyRentReminder(dayOfMonth: dueDay);
    }
    if (leaseReminder) {
      final lease = await DatabaseHelper.instance.getLatestLease();
      if (lease != null) {
        final end = DateTime.tryParse(lease.leaseEndDate);
        if (end != null) {
          await NotificationService.scheduleLeaseRenewalReminders(
            leaseEndDate: end,
            daysBefore: const [60, 30, 14],
          );
        }
      }
    }
  }

  Future<void> _saveSettings() async => _save();

  void _showProUpgradeSheet() {
    showRentlogProUpgradeBottomSheet(
      context,
      isParentMounted: () => mounted,
      ctaColor: const Color(0xFF00C48C),
      onUnlocked: () async {
        if (!mounted) return;
        setState(() {
          _proFuture = Future.value(true);
        });
      },
      onRestoreComplete: (restoredPro) async {
        if (!mounted) return;
        if (restoredPro) {
          setState(() {
            _proFuture = Future.value(true);
          });
        }
      },
    );
  }

  Future<void> _handleAppLockToggle(bool value) async {
    if (!value) {
      setState(() => _appLockEnabled = false);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_lock_enabled', false);
      } catch (_) {}
      return;
    }

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        showAppSnackBar('Biometric authentication not available on this device');
        setState(() => _appLockEnabled = false);
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock RentLog',
      );
      if (!authenticated) {
        showAppSnackBar('Biometric authentication not available on this device');
        setState(() => _appLockEnabled = false);
        return;
      }

      setState(() => _appLockEnabled = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_lock_enabled', true);
      } catch (_) {}
    } catch (_) {
      showAppSnackBar('Biometric authentication not available on this device');
      setState(() => _appLockEnabled = false);
    }
  }

  Future<bool> _requestNotificationPermission() async {
    debugPrint('Permission status: ${await Permission.notification.status}');
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      if (status.isPermanentlyDenied) {
        final shouldOpenSettings = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(sheetContext).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications Disabled',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'To enable them, go to Settings → RentLog → Notifications',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8A8A8A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
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
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Open Settings'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF8A8A8A)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
        return false;
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: 20, bottom: 14),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            FutureBuilder<bool>(
              future: _proFuture,
              builder: (context, snapshot) {
                final isPro = snapshot.data ?? PurchaseService.isDebugProEnabled;
                if (isPro) return const SizedBox.shrink();
                return _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RENTLOG PRO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A8A8A),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 16,
                            color: Color(0xFF00C48C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Multiple properties',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 16,
                            color: Color(0xFF00C48C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'PDF export',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 16,
                            color: Color(0xFF00C48C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Full payment history',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 16,
                            color: Color(0xFF00C48C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cloud Backup',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showProUpgradeSheet,
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Upgrade to Pro',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REMINDERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A8A8A),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rent due reminder',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Switch(
                        activeColor: const Color(0xFF00C48C),
                        value: rentReminder,
                        onChanged: (value) async {
                          if (value) {
                            await _requestNotificationPermission();
                          }
                          setState(() => rentReminder = value);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  if (rentReminder) ...[
                    _pickerRow(
                      label: 'Remind me on',
                      value: 'Day $dueDay of month',
                      onTap: _showDueDayPicker,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Divider(height: 1, color: Color(0xFFE8ECF0)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lease renewal reminder',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Switch(
                        activeColor: const Color(0xFF00C48C),
                        value: leaseReminder,
                        onChanged: (value) async {
                          if (value) {
                            await _requestNotificationPermission();
                          }
                          setState(() => leaseReminder = value);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  if (leaseReminder)
                    _pickerRow(
                      label: 'Remind me',
                      value: '$reminderDays days before expiry',
                      onTap: _showLeaseReminderPicker,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SECURITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A8A8A),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Lock',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Require Face ID / fingerprint to open RentLog',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A8A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        activeColor: const Color(0xFF00C48C),
                        value: _appLockEnabled,
                        onChanged: _handleAppLockToggle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            FutureBuilder<bool>(
              future: _proFuture,
              builder: (context, snapshot) {
                final isPro =
                    snapshot.data ?? PurchaseService.isDebugProEnabled;
                if (!isPro) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BACKUP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A8A8A),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<String?>(
                            future: _lastBackupDateFuture,
                            builder: (context, snapshot) {
                              final date = snapshot.data;
                              return Text(
                                date != null
                                    ? 'Last backed up: $date'
                                    : 'Never backed up',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A8A8A),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () async {
                              final ok = await BackupService.backupNow();
                              if (!context.mounted) return;
                              showAppSnackBar(
                                ok ? 'Backup complete' : 'Backup failed',
                              );
                              if (ok && mounted) {
                                setState(() {
                                  _lastBackupDateFuture =
                                      BackupService.getLastBackupDate();
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Back Up Now',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () async {
                              final confirmed = await showConfirmDialog(
                                context,
                                title: 'Restore Backup',
                                content:
                                    'This will replace all your current data with the backup. This cannot be undone.',
                                confirmLabel: 'Restore',
                              );
                              if (!confirmed || !context.mounted) {
                                return;
                              }
                              final ok =
                                  await BackupService.restoreBackup();
                              if (!context.mounted) return;
                              showAppSnackBar(
                                ok
                                    ? 'Restore complete. Restart the app.'
                                    : 'Restore failed',
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Restore Backup',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8A8A8A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACCOUNT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A8A8A),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'App Version',
                        style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                      ),
                      Text(
                        _appVersion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE8ECF0)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EarnScreen()),
                      );
                    },
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.card_giftcard_outlined,
                                size: 18,
                                color: Color(0xFF1A1A1A),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Refer & Earn',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Color(0xFFCCCCCC),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE8ECF0)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showCurrencyPicker,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Currency',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _currencySymbol,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF8A8A8A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Color(0xFFCCCCCC),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFBD59)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DEBUG: Pro Access',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              'Toggle Pro features without purchasing',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A8A8A),
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: PurchaseService.isDebugProEnabled,
                          onChanged: (_) {
                            PurchaseService.toggleDebugPro();
                            setState(() {
                              _proFuture = PurchaseService.isDebugProEnabled
                                  ? Future.value(true)
                                  : PurchaseService.isProUser();
                            });
                          },
                          activeColor: const Color(0xFF00C48C),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            type: MaterialType.transparency,
                            child: OutlinedButton(
                              onPressed: () =>
                                  NotificationService.scheduleTestRentReminder(
                                    days: dueDay,
                                  ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1A1A1A)),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1A1A1A),
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              child: const Text(
                                'Test Rent Reminder',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Material(
                            type: MaterialType.transparency,
                            child: OutlinedButton(
                              onPressed: () =>
                                  NotificationService.scheduleTestLeaseReminder(
                                    days: reminderDays,
                                  ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1A1A1A)),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1A1A1A),
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              child: const Text(
                                'Test Lease Reminder',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
          ],
        ),
      ),
    );
  }

  void _showDueDayPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rent due reminder',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C48C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F1F3)),
            Expanded(
              child: ListView.builder(
                itemCount: 28,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isSelected = dueDay == day;
                  return GestureDetector(
                    onTap: () async {
                      setState(() => dueDay = day);
                      Navigator.pop(context);
                      await _saveSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF0F1F3)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Day $day',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check,
                              size: 18,
                              color: Color(0xFF00C48C),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaseReminderPicker() {
    final options = [14, 30, 60, 90];
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
              'Lease renewal reminder',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (days) => GestureDetector(
                onTap: () async {
                  setState(() => reminderDays = days);
                  Navigator.pop(context);
                  await _saveSettings();
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
                        '$days days before expiry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: reminderDays == days
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (reminderDays == days)
                        const Icon(
                          Icons.check,
                          size: 18,
                          color: Color(0xFF00C48C),
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

  void _showCurrencyPicker() {
    final currencies = [
      {'symbol': '\$', 'label': 'USD — US Dollar'},
      {'symbol': '£', 'label': 'GBP — British Pound'},
      {'symbol': '€', 'label': 'EUR — Euro'},
      {'symbol': '₹', 'label': 'INR — Indian Rupee'},
      {'symbol': '¥', 'label': 'JPY — Japanese Yen'},
      {'symbol': 'A\$', 'label': 'AUD — Australian Dollar'},
      {'symbol': 'C\$', 'label': 'CAD — Canadian Dollar'},
      {'symbol': 'S\$', 'label': 'SGD — Singapore Dollar'},
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
            const Text(
              'Currency',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...currencies.map(
              (c) => GestureDetector(
                onTap: () {
                  setState(() => _currencySymbol = c['symbol']!);
                  _saveSettings();
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
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                c['symbol']!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            c['label']!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      if (_currencySymbol == c['symbol'])
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

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: child,
    );
  }

  Widget _pickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF8A8A8A)),
          ],
        ),
      ),
    );
  }
}

