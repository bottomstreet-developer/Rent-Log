import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        color: Colors.white,
        width: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration premiumCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xFFE8ECF0)),
    borderRadius: BorderRadius.circular(16),
  );
}

/// Root tab bar: uniform icon size and label style for every destination.
class RentLogRootNavigationBar extends StatelessWidget {
  const RentLogRootNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double _navIconSize = 24;
  static const TextStyle _navLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: const Color(0xFF1A1A1A),
        unselectedItemColor: const Color(0xFFCCCCCC),
        selectedLabelStyle: _navLabelStyle,
        unselectedLabelStyle: _navLabelStyle,
        iconSize: _navIconSize,
        currentIndex: selectedIndex,
        onTap: onDestinationSelected,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card_outlined),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handyman_outlined),
            label: 'Maintenance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
