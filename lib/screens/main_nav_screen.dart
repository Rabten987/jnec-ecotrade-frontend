import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'my_listing_items_tab.dart';
import 'post_tab.dart';
import 'offers_received_tab.dart';
import 'profile_tab.dart';

/// ✅ Hosts all 5 main tabs (Home, My Listings, Post, Offers, Profile)
/// inside a real PageView so swiping left/right slides smoothly between
/// tabs — exactly like tapping the bottom nav icons, but with the visual
/// sliding animation. Each tab keeps its own loaded data and scroll
/// position via AutomaticKeepAliveClientMixin (set inside each *Tab widget).
class MainNavScreen extends StatefulWidget {
  /// Which tab to open first (0=Home, 1=My Listings, 2=Post, 3=Offers, 4=Profile)
  final int initialIndex;

  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex   = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    // ✅ Animated slide to the tapped tab — same visual feel as swiping
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Each tab manages its own AppBar internally (Scaffold inside
      // Scaffold is fine here since only the inner one renders an AppBar)
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        // ✅ True sliding PageView — swiping drags both screens visibly,
        // exactly like the reference screenshot
        children: const [
          HomeTab(),
          MyListingItemsTab(),
          PostTab(),
          OffersReceivedTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal.shade600,
        unselectedItemColor: Colors.black45,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'My Listings'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined), activeIcon: Icon(Icons.add_box), label: 'Post'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer_outlined), activeIcon: Icon(Icons.local_offer), label: 'Offers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}