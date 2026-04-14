import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const accent = Color(0xFF1A1A1A);
    final pages = const [
      _OnboardingPage(
        icon: Icons.home_work_outlined,
        title: 'Your rent records, finally organised',
        subtitle: 'Log every payment. Store your lease. Track increases.',
      ),
      _OnboardingPage(
        icon: Icons.lock_outline,
        title: 'Independent of your landlord',
        subtitle:
            'Everything stored privately on your device. No account needed. No landlord access.',
      ),
      _OnboardingPage(
        icon: Icons.notifications_active_outlined,
        title: 'Never miss rent day',
        subtitle: 'Reminders before rent is due and before your lease expires.',
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (value) {
                  if (_index == value || !mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _index = value);
                  });
                },
                itemBuilder: (_, i) => pages[i],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _index ? accent : const Color(0xFFE4E6EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              40 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _index == 2
                    ? widget.onGetStarted
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                      ),
                child: Text(
                  _index == 2 ? 'Get Started' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          const Text(
            'RentLog',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8A8A8A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
