import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_screen.dart';
import 'my_listing_items_screen.dart';
import 'post_screen.dart';
import 'offers_received_screen.dart';
import 'profile_screen.dart';

/// ✅ Shared bottom navigation bar used by Home, My Listing Items, Post,
/// Offers Received, and Profile screens so navigation is consistent
/// everywhere instead of only being available from Home.
///
/// [currentIndex] should be:
///   0 = Home, 1 = My Listings, 2 = Post, 3 = Offers, 4 = Profile
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  /// ✅ Central navigation logic — shared by tab taps AND swipe gestures
  /// so both trigger the exact same screen transition.
  static void goToTab(int targetIndex, int currentIndex) {
    if (targetIndex == currentIndex) return;
    if (targetIndex < 0 || targetIndex > 4) return; // out of range, ignore

    switch (targetIndex) {
      case 0:
        Get.offAll(() => const HomeScreen());
        break;
      case 1:
        Get.off(() => const MyListingItemsScreen());
        break;
      case 2:
        Get.off(() => const PostScreen());
        break;
      case 3:
        Get.off(() => const OffersReceivedScreen());
        break;
      case 4:
        Get.off(() => const ProfileScreen());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => goToTab(index, currentIndex),
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
    );
  }
}

/// ✅ Wrap any tab screen's body with this to enable swipe-left/swipe-right
/// navigation between the 5 main tabs — swiping triggers the exact same
/// Get.off()/Get.offAll() navigation as tapping the bottom nav icon.
///
/// Usage: wrap your Scaffold's `body:` value with
/// `SwipeNavWrapper(currentIndex: X, child: <your existing body>)`
class SwipeNavWrapper extends StatelessWidget {
  final int currentIndex;
  final Widget child;

  const SwipeNavWrapper({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // ✅ Require a deliberate swipe (not an accidental small drag)
        const threshold = 200.0;
        if (velocity < -threshold) {
          // Swiped left → go to next tab (e.g. Home → My Listings)
          AppBottomNav.goToTab(currentIndex + 1, currentIndex);
        } else if (velocity > threshold) {
          // Swiped right → go to previous tab (e.g. Post → My Listings)
          AppBottomNav.goToTab(currentIndex - 1, currentIndex);
        }
      },
      child: child,
    );
  }
}