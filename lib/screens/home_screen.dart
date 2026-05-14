import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jnec_ecotrade_app/screens/my_booking_screen.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import 'post_screen.dart';
import 'profile_screen.dart';
import 'my_listings_screen.dart';
import 'item_detail_screen.dart';
import 'notifications_screen.dart';
import 'cart_screen.dart';
import 'saved_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authController = Get.find<AuthController>();
  final _homeController = Get.put(HomeController());

  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

// ✅ Add this inside _HomeScreenState — replace your existing initState
  @override
  void initState() {
    super.initState();
    _homeController.loadItems();
    _homeController.loadUnreadCount();

    // ✅ Show contact prompt if Google login user has no phone
    //    Delayed so home screen builds first, then prompt appears after 2s
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController.showContactPromptIfNeeded();
    });
  }

  String _formatCategory(String cat) {
    if (cat == 'All') return 'All';
    return cat[0].toUpperCase() + cat.substring(1).replaceAll('_', ' ');
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.72,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),

            // ── Profile Avatar ──
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final avatar = _authController.userAvatar.value;

                      await showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => SafeArea(
                          child: Wrap(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: const Text('Profile Photo',
                                    style: TextStyle(fontSize: 16,
                                        fontWeight: FontWeight.bold, color: Colors.black87)),
                              ),
                              Divider(color: Colors.grey.shade200),
                              if (avatar.isNotEmpty)
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                                    child: Icon(Icons.image_outlined, color: Colors.teal.shade600),
                                  ),
                                  title: const Text('View Photo'),
                                  subtitle: const Text('View your profile photo'),
                                  onTap: () {
                                    Get.back();
                                    Get.dialog(Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: const EdgeInsets.all(16),
                                      child: Stack(children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.memory(base64Decode(avatar),
                                              fit: BoxFit.contain, width: double.infinity),
                                        ),
                                        Positioned(top: 8, right: 8,
                                          child: GestureDetector(
                                            onTap: () => Get.back(),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.6),
                                                  shape: BoxShape.circle),
                                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                                            ),
                                          ),
                                        ),
                                      ]),
                                    ));
                                  },
                                ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                                  child: Icon(Icons.photo_library_outlined, color: Colors.teal.shade600),
                                ),
                                title: const Text('Choose from Gallery'),
                                subtitle: const Text('Pick a photo from your gallery'),
                                onTap: () async {
                                  Get.back();
                                  final picked = await picker.pickImage(
                                      source: ImageSource.gallery, maxWidth: 400, imageQuality: 70);
                                  if (picked != null) {
                                    final bytes = await picked.readAsBytes();
                                    await _authController.updateAvatar(base64Encode(bytes));
                                  }
                                },
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                                  child: Icon(Icons.camera_alt_outlined, color: Colors.blue.shade600),
                                ),
                                title: const Text('Take a Photo'),
                                subtitle: const Text('Use your camera to take a photo'),
                                onTap: () async {
                                  Get.back();
                                  final picked = await picker.pickImage(
                                      source: ImageSource.camera, maxWidth: 400, imageQuality: 70);
                                  if (picked != null) {
                                    final bytes = await picked.readAsBytes();
                                    await _authController.updateAvatar(base64Encode(bytes));
                                  }
                                },
                              ),
                              if (avatar.isNotEmpty)
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                    child: Icon(Icons.delete_outline, color: Colors.red.shade600),
                                  ),
                                  title: const Text('Remove Photo'),
                                  subtitle: const Text('Reset to default avatar'),
                                  onTap: () async {
                                    Get.back();
                                    await _authController.updateAvatar('');
                                  },
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Obx(() {
                      final avatar = _authController.userAvatar.value;
                      return Stack(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: avatar.isNotEmpty
                                ? MemoryImage(base64Decode(avatar))
                                : null,
                            child: avatar.isEmpty
                                ? const Icon(Icons.person, size: 55, color: Colors.grey)
                                : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: Colors.teal.shade600, shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Obx(() => Text(_authController.userName.value,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Colors.black87))),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 8),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.black87, width: 1.5)),
                child: const Icon(Icons.person_outline, size: 20, color: Colors.black87),
              ),
              title: const Text('My Profile',
                  style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
              onTap: () { Get.back(); Get.to(() => const ProfileScreen()); },
            ),

            ListTile(
              leading: const Icon(Icons.check_box_outlined, size: 26, color: Colors.black87),
              title: const Text('My Booking',
                  style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
              onTap: () { Get.back(); Get.to(() => const MyBookingScreen()); },
            ),

            ListTile(
              leading: const Icon(Icons.favorite_border, size: 26, color: Colors.black87),
              title: const Text('Favourite',
                  style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
              onTap: () { Get.back(); Get.to(() => const SavedScreen()); },
            ),

            const Spacer(),
            Divider(color: Colors.grey.shade200),

            ListTile(
              leading: const Icon(Icons.power_settings_new, color: Colors.black87, size: 24),
              title: const Text('Log Out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
              onTap: () { Get.back(); _authController.logout(); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: const Icon(Icons.menu, size: 26),
                      ),
                      const SizedBox(width: 10),
                      Obx(() => Text('Hi ${_authController.userName.value}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  Row(
                    children: [
                      Obx(() {
                        final count = _homeController.unreadCount.value;
                        return IconButton(
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.notifications_outlined, size: 26),
                              if (count > 0)
                                Positioned(
                                  top: -4, right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                        color: Colors.red, shape: BoxShape.circle),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      count > 99 ? '99+' : '$count',
                                      style: const TextStyle(color: Colors.white,
                                          fontSize: 9, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: () async {
                            await Get.to(() => const NotificationsScreen());
                            _homeController.loadUnreadCount();
                          },
                        );
                      }),
                      IconButton(
                        icon: const Icon(Icons.power_settings_new, size: 24, color: Colors.black87),
                        onPressed: () => _authController.logout(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: Colors.black38, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => _homeController.search(val),
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Search items...',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 4),
              child: Text('Categories',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),

            const SizedBox(height: 8),

            // ── Categories ──
            SizedBox(
              height: 34,
              child: Obx(() {
                final selected = _homeController.selectedCategory.value;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _homeController.categories.length,
                  itemBuilder: (context, index) {
                    final cat        = _homeController.categories[index];
                    final isSelected = selected == cat;
                    return GestureDetector(
                      onTap: () => _homeController.selectCategory(cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.teal.shade600 : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected ? Colors.teal.shade600 : Colors.grey.shade300),
                        ),
                        child: Text(_formatCategory(cat),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            )),
                      ),
                    );
                  },
                );
              }),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Browse Items',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Obx(() => Text('${_homeController.items.length} items',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Items Grid ──
            Expanded(
              child: Obx(() {
                if (_homeController.isLoading.value) {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }
                if (_homeController.items.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No items found', style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                    ],
                  ));
                }
                return RefreshIndicator(
                  onRefresh: () => _homeController.loadItems(),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 10,
                      mainAxisSpacing: 10, childAspectRatio: 0.82,
                    ),
                    itemCount: _homeController.items.length,
                    itemBuilder: (context, index) =>
                        _buildItemCard(_homeController.items[index]),
                  ),
                );
              }),
            ),
          ],
        ),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Get.to(() => const MyListingsScreen());
          } else if (index == 2) {
            Get.to(() => const PostScreen())?.then((_) => _homeController.loadItems());
          } else if (index == 3) {
            Get.to(() => const CartScreen());
          } else if (index == 4) {
            Get.to(() => const ProfileScreen());
          } else {
            setState(() => _currentIndex = index);
          }
        },
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
              icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'My Cart'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    Uint8List? imageBytes;
    if (item['image'] != null && item['image'].toString().isNotEmpty) {
      try { imageBytes = base64Decode(item['image']); } catch (_) {}
    }

    // ✅ Check if auction item
    final auctionVal = item['auction_enabled'];
    final isAuction  = auctionVal == true || auctionVal == 1 || auctionVal.toString() == 'true';

    // ✅ Time left for auction
    String timeLeft = '';
    if (isAuction && item['auction_ends_at'] != null) {
      try {
        final endsAt = DateTime.parse(item['auction_ends_at']).toLocal();
        final now    = DateTime.now();
        if (now.isBefore(endsAt)) {
          final diff = endsAt.difference(now);
          if (diff.inDays > 0) {
            timeLeft = '${diff.inDays}d left';
          } else if (diff.inHours > 0) {
            timeLeft = '${diff.inHours}h left';
          } else {
            timeLeft = '${diff.inMinutes}m left';
          }
        } else {
          timeLeft = 'Ended';
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => Get.to(() => ItemDetailScreen(item: item)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            // ✅ Teal border for auction items
            color: isAuction ? Colors.teal.shade300 : Colors.grey.shade200,
            width: isAuction ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Image with auction badge overlay ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: SizedBox(
                    height: 120, width: double.infinity,
                    child: imageBytes != null
                        ? Image.memory(imageBytes, fit: BoxFit.contain, width: double.infinity)
                        : Container(
                            color: Colors.grey.shade100,
                            child: Icon(Icons.image_outlined, size: 32, color: Colors.grey.shade300)),
                  ),
                ),

                // ✅ Auction badge on top-left of image
                if (isAuction)
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gavel, color: Colors.white, size: 10),
                          const SizedBox(width: 3),
                          const Text('AUCTION',
                              style: TextStyle(color: Colors.white, fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Item Info ──
            Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['item_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Nu ${item['price']}',
                      style: TextStyle(color: Colors.teal.shade600, fontSize: 11,
                          fontWeight: FontWeight.w600)),

                  // ✅ Show time left for auction items
                  if (isAuction && timeLeft.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(timeLeft,
                        style: TextStyle(
                          fontSize: 10,
                          color: timeLeft == 'Ended' ? Colors.red : Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        )),
                  ],

                  const Spacer(), // ✅ pushes button to bottom
                  SizedBox(
                    width: double.infinity, height: 28,
                    child: ElevatedButton(
                      onPressed: () => Get.to(() => ItemDetailScreen(item: item)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        isAuction ? 'Bid Now' : 'View',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}