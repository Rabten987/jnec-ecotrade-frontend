import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:jnec_ecotrade_app/screens/admin/admin_category_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_feedback_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_home_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../utils/constants.dart';
import 'admin_item_manage_screen.dart';

const kAdminColor = Color(0xFF00897B);

class AdminItemsScreen extends StatefulWidget {
  const AdminItemsScreen({super.key});

  @override
  State<AdminItemsScreen> createState() =>
      _AdminItemsScreenState();
}

class _AdminItemsScreenState
    extends State<AdminItemsScreen> {

  List<dynamic> _items = [];

  final List<Map<String, dynamic>> _categories = [
    {
      'name':  'Stationary',
      'value': 'stationary',
      'icon':  Icons.edit_outlined
    },
    {
      'name':  'Clothing',
      'value': 'clothing',
      'icon':  Icons.checkroom_outlined
    },
    {
      'name':  'Furniture',
      'value': 'furniture',
      'icon':  Icons.chair_outlined
    },
    {
      'name':  'Kitchen Utensils',
      'value': 'kitchen_utensils',
      'icon':  Icons.kitchen_outlined
    },
    {
      'name':  'Electronic',
      'value': 'electronic',
      'icon':  Icons.devices_outlined
    },
    {
      'name':  'Miscellaneous',
      'value': 'miscellaneous',
      'icon':  Icons.category_outlined
    },
    {
      'name':  'Others',
      'value': 'others',
      'icon':  Icons.more_horiz_outlined
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadItems() async {
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/admin/items'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _items = jsonDecode(response.body);
        });
      }
    } catch (e) {
      Get.snackbar('Error',
          'Failed to load items: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kAdminColor,
        foregroundColor: Colors.white,
        title: const Text('Items',
            style: TextStyle(
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),

      // ── Body ──
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ── Item Manage ──
            _menuItem(
              icon: Icons.inventory_2_outlined,
              title: 'Manage Item',
              subtitle:
                  '${_items.length} total items',
              onTap: () => Get.to(
                () => AdminItemManageScreen(
                    items: _items,
                    onRefresh: _loadItems),
              ),
            ),

            const SizedBox(height: 12),

            // ── Item Category ──
            _menuItem(
              icon: Icons.category_outlined,
              title: 'Manage Category',
              subtitle:
                  '${_categories.length} categories',
              onTap: () => Get.to(
                () => AdminCategoryScreen(
                    items: _items,
                    categories: _categories),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kAdminColor,
        unselectedItemColor: Colors.black45,
        onTap: (index) {
          if (index == 0) {
            Get.offAll(
                () => const AdminHomeScreen());
          } else if (index == 1) {
            // Already here
          } else if (index == 2) {
            Get.to(
                () => const AdminFeedbackScreen());
          } else if (index == 3) {
            Get.to(
                () => const AdminProfileScreen());
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback_outlined),
            activeIcon: Icon(Icons.feedback),
            label: 'Feedback',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  } // ✅ End of build method

  // ✅ Menu item widget
  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
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
          border: Border.all(
              color: Colors.grey.shade200),
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
            Icon(icon,
                size: 26, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
} // ✅ End of class