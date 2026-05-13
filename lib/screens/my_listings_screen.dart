import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jnec_ecotrade_app/screens/cart_screen.dart';
import 'package:jnec_ecotrade_app/screens/post_screen.dart';
import 'package:jnec_ecotrade_app/screens/profile_screen.dart';
import 'booking_requests_screen.dart';
import 'my_listing_items_screen.dart';
import 'notifications_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'My Listings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // ✅ GetX back
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          // ✅ Notification button working
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () =>
                Get.to(() => const NotificationsScreen()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // My Listing Option
            _menuItem(
              icon: Icons.dashboard_customize_outlined,
              title: 'My Listing',
              onTap: () => Get.to(
                  () => const MyListingItemsScreen()),
            ),

            const SizedBox(height: 8),

            // Booking Requests Option
            _menuItem(
              icon: Icons.description_outlined,
              title: 'Booking Requests',
              onTap: () => Get.to(
                  () => const BookingRequestsScreen()),
            ),
          ],
        ),
      ),

      // ✅ Bottom Navigation with GetX
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal.shade600,
        unselectedItemColor: Colors.black45,
        onTap: (index) {
          if (index == 0) {
            Get.back(); // ✅ Home
          } else if (index == 1) {
            // Already here
          } else if (index == 2) {
            Get.to(() => const PostScreen());
          } else if (index == 3) {
            Get.to(() => const CartScreen());
          } else if (index == 4) {
            Get.to(() => const ProfileScreen());
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
                Icons.dashboard_customize_outlined),
            activeIcon:
                Icon(Icons.dashboard_customize),
            label: 'My Listings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: ' Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ✅ Removed BuildContext parameter - not needed with GetX
  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: Colors.black87),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}