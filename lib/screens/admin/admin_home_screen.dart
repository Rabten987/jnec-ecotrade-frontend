import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_category_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_feedback_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_item_manage_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_items_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_profile_screen.dart';
import 'package:jnec_ecotrade_app/screens/admin/admin_users_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../controllers/auth_controller.dart';
import 'admin_recycle_bin_screen.dart';

const kAdminColor = Color(0xFF00897B);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() =>
      _AdminHomeScreenState();
}

class _AdminHomeScreenState
    extends State<AdminHomeScreen> {
  final _authController =
      Get.find<AuthController>();
  final _scaffoldKey =
      GlobalKey<ScaffoldState>();

  int _currentIndex    = 0;
  int _totalItems      = 0;
  int _totalFeedback   = 0;
  int _totalCategories = 0;
  int _totalUsers      = 0;
  List<dynamic> _recentActivities = [];
  List<dynamic> _allItems         = [];
  bool _isLoading   = false;
  String _adminAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadAllItems();
    _loadAdminAvatar();
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // ✅ Load admin avatar
  Future<void> _loadAdminAvatar() async {
    final prefs =
        await SharedPreferences.getInstance();
    setState(() {
      _adminAvatar =
          prefs.getString('admin_avatar') ?? '';
    });
  }

  // ✅ Save admin avatar
  Future<void> _saveAdminAvatar(
      String base64Str) async {
    try {
      final prefs =
          await SharedPreferences.getInstance();
      await prefs.setString(
          'admin_avatar', base64Str);

      final token = await _getToken();
      await http.post(
        Uri.parse(
            '${Constants.baseUrl}/admin/profile/avatar'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'avatar': base64Str}),
      );

      setState(() => _adminAvatar = base64Str);

      Get.snackbar(
        base64Str.isEmpty ? 'Removed' : 'Updated',
        base64Str.isEmpty
            ? 'Profile photo removed!'
            : 'Profile photo updated!',
        backgroundColor: kAdminColor,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', 'Error: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ✅ Show avatar options
  Future<void> _showAvatarOptions() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 8),
              child: const Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),

            // ✅ View - only if has image
            if (_adminAvatar.isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAdminColor
                        .withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.image_outlined,
                      color: kAdminColor),
                ),
                title: const Text('View Photo'),
                onTap: () {
                  Get.back();
                  Get.dialog(
                    Dialog(
                      backgroundColor:
                          Colors.transparent,
                      insetPadding:
                          const EdgeInsets.all(16),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(16),
                            child: Image.memory(
                              base64Decode(
                                  _adminAvatar),
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  Get.back(),
                              child: Container(
                                padding:
                                    const EdgeInsets
                                        .all(6),
                                decoration:
                                    BoxDecoration(
                                  color: Colors.black
                                      .withOpacity(
                                          0.6),
                                  shape:
                                      BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.close,
                                    color:
                                        Colors.white,
                                    size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // ✅ Gallery
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kAdminColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                    Icons.photo_library_outlined,
                    color: kAdminColor),
              ),
              title:
                  const Text('Choose from Gallery'),
              onTap: () async {
                Get.back();
                final picker = ImagePicker();
                final picked =
                    await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 400,
                  imageQuality: 70,
                );
                if (picked != null) {
                  final bytes =
                      await picked.readAsBytes();
                  await _saveAdminAvatar(
                      base64Encode(bytes));
                }
              },
            ),

            // ✅ Camera
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.blue.shade600),
              ),
              title: const Text('Take a Photo'),
              onTap: () async {
                Get.back();
                final picker = ImagePicker();
                final picked =
                    await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 400,
                  imageQuality: 70,
                );
                if (picked != null) {
                  final bytes =
                      await picked.readAsBytes();
                  await _saveAdminAvatar(
                      base64Encode(bytes));
                }
              },
            ),

            // ✅ Remove - only if has image
            if (_adminAvatar.isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline,
                      color: Colors.red.shade600),
                ),
                title: const Text('Remove Photo'),
                onTap: () async {
                  Get.back();
                  await _saveAdminAvatar('');
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/admin/stats'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalItems =
              data['total_items'] ?? 0;
          _totalFeedback =
              data['total_feedback'] ?? 0;
          _totalCategories =
              data['total_categories'] ?? 0;
          _totalUsers =
              data['total_users'] ?? 0;
          _recentActivities =
              data['recent_activities'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadAllItems() async {
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
          _allItems = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Items error: $e');
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadStats(),
      _loadAllItems(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu,
              color: kAdminColor),
          onPressed: () => _scaffoldKey
              .currentState
              ?.openDrawer(),
        ),
        title: const Text(
          'Admin',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
                Icons.power_settings_new,
                color: Colors.black87),
            onPressed: () =>
                _authController.logout(),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: kAdminColor))
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    // ── Stats Grid 2x2 ──
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.2,
                      children: [

                        _statCard(
                          title: 'Manage Item',
                          count: _totalItems,
                          onTap: () async {
                            await Get.to(
                              () =>
                                  AdminItemManageScreen(
                                items: _allItems,
                                onRefresh:
                                    _refreshAll,
                              ),
                            );
                            _refreshAll();
                          },
                        ),

                        _statCard(
                          title: 'Manage User',
                          count: _totalUsers,
                          onTap: () async {
                            await Get.to(() =>
                                const AdminUsersScreen());
                            _loadStats();
                          },
                        ),

                        _statCard(
                          title: 'Feedback',
                          count: _totalFeedback,
                          onTap: () async {
                            await Get.to(() =>
                                const AdminFeedbackScreen());
                            _loadStats();
                          },
                        ),

                        _statCard(
                          title: 'Item Category',
                          count: _totalCategories,
                          onTap: () async {
                            await Get.to(
                              () =>
                                  AdminCategoryScreen(
                                items: _allItems,
                                categories:
                                    const [],
                              ),
                            );
                            _refreshAll();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Recent Activities ──
                    const Text(
                      'Recent Activities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _recentActivities.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets
                                      .all(20),
                              child: Text(
                                'No recent activities',
                                style: TextStyle(
                                    color: Colors
                                        .grey
                                        .shade400),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount:
                                _recentActivities
                                    .length,
                            itemBuilder:
                                (context, index) {
                              final activity =
                                  _recentActivities[
                                      index];
                              final action =
                                  activity[
                                          'action'] ??
                                      '';

                              // ✅ Icon by type
                              IconData activityIcon;
                              Color iconColor;

                              if (action.contains(
                                  'registration')) {
                                activityIcon = Icons
                                    .person_add_outlined;
                                iconColor =
                                    Colors.blue.shade600;
                              } else if (action
                                  .contains('Posted')) {
                                activityIcon =
                                    Icons.upload_outlined;
                                iconColor = kAdminColor;
                              } else if (action
                                  .contains('feedback')) {
                                activityIcon =
                                    Icons.star_outline;
                                iconColor = Colors
                                    .orange.shade600;
                              } else {
                                activityIcon = Icons
                                    .notifications_outlined;
                                iconColor =
                                    Colors.grey.shade600;
                              }

                              return Container(
                                margin:
                                    const EdgeInsets
                                        .only(
                                            bottom: 8),
                                padding:
                                    const EdgeInsets
                                        .all(12),
                                decoration:
                                    BoxDecoration(
                                  color: const Color(
                                      0xFFE8F5E9),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              12),
                                  border: Border.all(
                                    color: kAdminColor
                                        .withOpacity(
                                            0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors
                                          .black
                                          .withOpacity(
                                              0.04),
                                      blurRadius: 4,
                                      offset:
                                          const Offset(
                                              0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          iconColor
                                              .withOpacity(
                                                  0.12),
                                      child: Icon(
                                          activityIcon,
                                          color:
                                              iconColor,
                                          size: 20),
                                    ),
                                    const SizedBox(
                                        width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            activity[
                                                    'name'] ??
                                                '',
                                            style:
                                                const TextStyle(
                                              color: Colors
                                                  .black87,
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                              fontSize:
                                                  14,
                                            ),
                                          ),
                                          Text(
                                            action,
                                            style:
                                                TextStyle(
                                              color: Colors
                                                  .grey
                                                  .shade600,
                                              fontSize:
                                                  12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),

      // ── Bottom Nav ──
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kAdminColor,
        unselectedItemColor: Colors.black45,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Get.to(
                    () => const AdminItemsScreen())
                ?.then((_) => _refreshAll());
          } else if (index == 2) {
            Get.to(() =>
                    const AdminFeedbackScreen())
                ?.then((_) => _loadStats());
          } else if (index == 3) {
            Get.to(
                    () => const AdminProfileScreen())
                ?.then((_) {
              _loadStats();
              _loadAdminAvatar();
            });
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
  }

  // ✅ Stat Card — 3D shadow effect
  Widget _statCard({
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kAdminColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 0,
              spreadRadius: 0,
              offset: const Offset(6, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(4, 8),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.15),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(-3, -3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                height: 1,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(5, 5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(4, 4),
                    blurRadius: 3,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Drawer
  Widget _buildDrawer() {
    return Drawer(
      width:
          MediaQuery.of(context).size.width * 0.70,
      child: SafeArea(
        child: Column(
          children: [

            // ✅ Header with Avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: kAdminColor,
              child: Column(
                children: [

                  // ✅ Tappable Avatar
                  GestureDetector(
                    onTap: _showAvatarOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor:
                              Colors.white,
                          backgroundImage:
                              _adminAvatar.isNotEmpty
                                  ? MemoryImage(
                                      base64Decode(
                                          _adminAvatar))
                                  : null,
                          child: _adminAvatar.isEmpty
                              ? const Icon(
                                  Icons
                                      .admin_panel_settings,
                                  size: 40,
                                  color: kAdminColor)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding:
                                const EdgeInsets.all(
                                    4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: kAdminColor,
                                  width: 1.5),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 12,
                              color: kAdminColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ✅ Name
                  Obx(() => Text(
                        _authController
                            .userName.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold),
                      )),

                  // ✅ Email
                  Obx(() => Text(
                        _authController
                            .userEmail.value,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12),
                      )),
                ],
              ),
            ),

            // ✅ Menu Items
            ListTile(
              leading: const Icon(Icons.dashboard,
                  color: kAdminColor),
              title: const Text('Dashboard'),
              onTap: () => Get.back(),
            ),
            ListTile(
              leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: kAdminColor),
              title: const Text('Manage Items'),
              onTap: () {
                Get.back();
                Get.to(() =>
                        const AdminItemsScreen())
                    ?.then((_) => _refreshAll());
              },
            ),
            ListTile(
              leading: const Icon(
                  Icons.people_outline,
                  color: kAdminColor),
              title: const Text('Manage Users'),
              onTap: () {
                Get.back();
                Get.to(() =>
                        const AdminUsersScreen())
                    ?.then((_) => _loadStats());
              },
            ),
            ListTile(
              leading: const Icon(
                  Icons.category_outlined,
                  color: kAdminColor),
              title: const Text('Categories'),
              onTap: () {
                Get.back();
                Get.to(() => AdminCategoryScreen(
                        items: _allItems,
                        categories: const []))
                    ?.then((_) => _refreshAll());
              },
            ),
            ListTile(
              leading: const Icon(
                  Icons.feedback_outlined,
                  color: kAdminColor),
              title: const Text('Feedback'),
              onTap: () {
                Get.back();
                Get.to(() =>
                        const AdminFeedbackScreen())
                    ?.then((_) => _loadStats());
              },
            ),

            ListTile(
                leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red),
                title: const Text('Recycle Bin',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Get.back();
                  Get.to(() =>
                      const AdminRecycleBinScreen());
                },
              ),

            const Spacer(),

            // ✅ Logout
            ListTile(
              leading: const Icon(Icons.logout,
                  color: Colors.red),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red)),
              onTap: () {
                Get.back();
                _authController.logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}