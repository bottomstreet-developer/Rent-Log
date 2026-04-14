import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:local_auth/local_auth.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/add_maintenance_screen.dart';
import 'screens/add_payment_screen.dart';
import 'screens/earn_screen.dart';
import 'screens/lease_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/rent_increase_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'utils/app_feedback.dart';
import 'utils/currency_notifier.dart';
import 'widgets/app_chrome.dart';

class AppColors {
  static const primary = Color(0xFF1A1A1A);
  static const accent = Color(0xFF00C48C);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF8F9FA);
  static const border = Color(0xFFF0F1F3);
  static const borderStrong = Color(0xFFE4E6EA);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textTertiary = Color(0xFFB0B0B0);
  static const success = Color(0xFF00C48C);
  static const successSurface = Color(0xFFF0FBF7);
  static const warning = Color(0xFFFFB020);
  static const warningSurface = Color(0xFFFFFBF0);
  static const error = Color(0xFFFF4757);
  static const errorSurface = Color(0xFFFFF0F1);
}

final ValueNotifier<int> rentLogTabNotifier = ValueNotifier<int>(0);

final RouteObserver<PageRoute<dynamic>> rentLogRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
bool suppressLock = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Color(0xFF1A1A1A)),
            SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Please restart the app',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8A8A8A),
              ),
            ),
          ],
        ),
      ),
    );
  };
  try {
    await PurchaseService.init().timeout(const Duration(seconds: 10));
  } catch (_) {}
  try {
    await _ensureUserCode();
    await _captureReferrer();
  } catch (_) {}
  try {
    await NotificationService.init();
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('currency_symbol');
    if (saved != null && saved.isNotEmpty) {
      currencyNotifier.value = saved;
    }
  } catch (_) {}
  runApp(const RentLogApp());
}

Future<void> _ensureUserCode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('user_code');
    if (existing != null && existing.trim().isNotEmpty) return;
    final customerInfo = await Purchases.getCustomerInfo();
    final originalAppUserId = customerInfo.originalAppUserId;
    if (originalAppUserId.trim().isEmpty) return;
    await prefs.setString('user_code', originalAppUserId);
    await Purchases.setAttributes({'user_code': originalAppUserId});
  } catch (_) {}
}

Future<void> _captureReferrer() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('referring_creator');
    if (existing != null && existing.trim().isNotEmpty) return;
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final details = await PlayInstallReferrer.installReferrer;
      final rawReferrer = (details.installReferrer ?? '').trim();
      if (rawReferrer.isEmpty) return;
      final normalized =
          rawReferrer.startsWith('?') ? rawReferrer.substring(1) : rawReferrer;
      final params = Uri.splitQueryString(normalized);
      final creator = (params['utm_campaign'] ?? '').trim();
      if (creator.isEmpty || creator.toLowerCase() == 'organic') return;

      await prefs.setString('referring_creator', creator);
      await PurchaseService.setReferringCreator(creator);
    } else if (Platform.isIOS) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey('referring_creator')) return;
        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
        final text = (clipboardData?.text ?? '').trim();
        if (text.startsWith('paprclip_ref:')) {
          final creator = text.replaceFirst('paprclip_ref:', '').trim();
          if (creator.isNotEmpty) {
            await prefs.setString('referring_creator', creator);
            await PurchaseService.setReferringCreator(creator);
            await Clipboard.setData(const ClipboardData(text: ''));
            debugPrint('Referrer captured (iOS clipboard): $creator');
          }
        }
      } catch (e) {
        debugPrint('iOS referrer capture failed: $e');
      }
    }
  } catch (_) {}
}

class RentLogApp extends StatelessWidget {
  const RentLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light(useMaterial3: true);
    return MaterialApp(
      title: 'RentLog',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      navigatorObservers: [rentLogRouteObserver],
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          tertiary: AppColors.accent,
          secondaryContainer: AppColors.accent.withValues(alpha: 0.2),
          tertiaryContainer: AppColors.accent.withValues(alpha: 0.2),
          surface: AppColors.surface,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),
        chipTheme: base.chipTheme.copyWith(
          selectedColor: AppColors.accent.withValues(alpha: 0.2),
          secondarySelectedColor: AppColors.accent.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.all(const IconThemeData(size: 24)),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.4),
          ),
        ),
      ),
      home: const AppEntry(),
      routes: {
        '/lease': (_) => const LeaseScreen(),
        '/payments': (_) => const PaymentsScreen(),
        '/add_payment': (_) => const AddPaymentScreen(),
        '/maintenance': (_) => const MaintenanceScreen(),
        '/add_maintenance': (_) => const AddMaintenanceScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/rent_increase': (_) => const RentIncreaseScreen(),
        '/earn': (_) => const EarnScreen(),
      },
    );
  }
}

int _compareAppStoreVersion(String store, String current) {
  List<int> parts(String v) {
    return v
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  final sa = parts(store);
  final sb = parts(current);
  final n = sa.length > sb.length ? sa.length : sb.length;
  for (var i = 0; i < n; i++) {
    final ai = i < sa.length ? sa[i] : 0;
    final bi = i < sb.length ? sb[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> with WidgetsBindingObserver {
  bool _loading = true;
  bool _locked = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (suppressLock) return;
      SharedPreferences.getInstance().then((prefs) {
        final lockEnabled = prefs.getBool('app_lock_enabled') ?? false;
        if (!mounted || !lockEnabled) return;
        setState(() => _locked = true);
      });
    }
  }

  Future<void> _init() async {
    bool lockEnabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      lockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    } catch (_) {
      lockEnabled = false;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _locked = lockEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_locked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'RentLog',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
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
                    onPressed: () async {
                      try {
                        final authenticated = await _localAuth.authenticate(
                          localizedReason: 'Unlock RentLog',
                        );
                        if (!mounted) return;
                        if (authenticated) {
                          setState(() => _locked = false);
                        }
                      } catch (_) {}
                    },
                    child: const Text('Unlock'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const RentLogShell();
  }
}

class RentLogShell extends StatefulWidget {
  const RentLogShell({super.key});

  @override
  State<RentLogShell> createState() => _RentLogShellState();
}

class _RentLogShellState extends State<RentLogShell> {
  int _index = 0;
  final _pages = [
    const HomeScreen(),
    const PaymentsScreen(),
    const MaintenanceScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    rentLogTabNotifier.addListener(_onTabRequested);
    _checkForUpdate();
  }

  @override
  void dispose() {
    rentLogTabNotifier.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final next = rentLogTabNotifier.value;
    if (next == _index) return;
    if (!mounted) return;
    setState(() => _index = next);
  }

  Future<void> _checkForUpdate() async {
    if (Platform.isAndroid) {
      try {
        final updateInfo = await InAppUpdate.checkForUpdate();
        if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
        }
      } catch (e) {
        debugPrint('InAppUpdate check failed: $e');
      }
    } else if (Platform.isIOS) {
      await _checkIOSUpdateFromShell();
    }
  }

  Future<void> _checkIOSUpdateFromShell() async {
    if (!kReleaseMode) return;
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
      if (!mounted) return;
      final response = await http.get(
        Uri.parse(
          'https://itunes.apple.com/lookup?bundleId=com.paprclip.rentlog',
        ),
      );
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return;
      final results = data['results'];
      if (results is! List || results.isEmpty) return;
      final first = results[0];
      if (first is! Map<String, dynamic>) return;
      final storeVersion = first['version']?.toString();
      if (storeVersion == null || storeVersion.isEmpty) return;
      final info = await PackageInfo.fromPlatform();
      if (_compareAppStoreVersion(storeVersion, info.version) <= 0) return;
      if (!mounted) return;
      await Future.microtask(() async {
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RENTLOG',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A8A8A),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Update Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A new version is available with improvements and bug fixes. Please update to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('https://apps.apple.com/app/id6761757073');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: const Text('Update Now'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Version $storeVersion available',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
              ],
            ),
          ),
        );
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: RentLogRootNavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          rentLogTabNotifier.value = value;
        },
      ),
    );
  }
}
