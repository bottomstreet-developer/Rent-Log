import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  bool _loading = true;
  String? _userCode;
  double _totalEarned = 0;
  int _referredUsers = 0;
  late final TapGestureRecognizer _payoutEmailTap;

  String get _referralLink =>
      _userCode == null ? '' : 'paprclip.app/rentlog/ref/${_userCode!}';

  String get _displayReferralLink =>
      (_userCode == null || _userCode!.trim().isEmpty)
      ? 'paprclip.app/rentlog/ref/yourname'
      : _referralLink;

  @override
  void initState() {
    super.initState();
    _payoutEmailTap = TapGestureRecognizer()..onTap = _emailPayout;
    _loadData();
  }

  @override
  void dispose() {
    _payoutEmailTap.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('user_code');
      if (!mounted) return;
      setState(() => _userCode = code);
      if (code != null && code.isNotEmpty) {
        await _fetchStats(code);
      }
    } catch (_) {
      // Keep default values on failure.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchStats(String code) async {
    try {
      final uri = Uri.parse('https://paprclip.app/stats/$code');
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return;
      final earnedRaw =
          data['total_earned'] ?? data['earned'] ?? data['totalEarned'] ?? 0;
      final referredRaw =
          data['referred_users'] ?? data['users'] ?? data['referredUsers'] ?? 0;
      final earned = earnedRaw is num
          ? earnedRaw.toDouble()
          : double.tryParse('$earnedRaw') ?? 0;
      final referred = referredRaw is num
          ? referredRaw.toInt()
          : int.tryParse('$referredRaw') ?? 0;
      if (!mounted) return;
      setState(() {
        _totalEarned = earned;
        _referredUsers = referred;
      });
    } catch (_) {
      // Keep default values on failure.
    }
  }

  Future<void> _copyLink() async {
    if (_referralLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _referralLink));
  }

  Future<void> _shareLink() async {
    if (_referralLink.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Track your rent payments with RentLog — your personal rent tracker. $_referralLink',
      ),
    );
  }

  Future<void> _emailPayout() async {
    final uri = Uri.parse('mailto:payout@paprclip.app');
    await launchUrl(uri);
  }

  Widget _header(BuildContext context) {
    return SafeArea(
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const Spacer(),
            const Text(
              'Refer & Earn',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your referral link',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8A8A8A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE8ECF0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _displayReferralLink,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _copyLink,
                                      child: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _copyLink,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46),
                                        side: const BorderSide(
                                          color: Color(0xFFE4E6EA),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Copy link'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _shareLink,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46),
                                        backgroundColor:
                                            const Color(0xFF1A1A1A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Share link'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '30%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'COMMISSION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8A8A8A),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Lifetime',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'DURATION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8A8A8A),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '\$10',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'MIN. PAYOUT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8A8A8A),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _card(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Earned',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8A8A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '\$${_totalEarned.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00C48C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 52,
                                color: const Color(0xFFE8ECF0),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Referred Users',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8A8A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '$_referredUsers',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
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
                                'How it works',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '1. Copy your unique link above',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8A8A8A),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '2. Share with your audience',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8A8A8A),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '3. Earn 30% of every subscription they buy, paid monthly to your PayPal',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8A8A8A),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '4. As long as your referral stays subscribed, you keep earning every single month',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8A8A8A),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8A8A8A),
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text:
                                          '5. Once your earnings reach \$10, email us at ',
                                    ),
                                    TextSpan(
                                      text: 'payout@paprclip.app',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1A1A1A),
                                        height: 1.5,
                                      ),
                                      recognizer: _payoutEmailTap,
                                    ),
                                    const TextSpan(
                                      text:
                                          ' to request your PayPal payout',
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
}
