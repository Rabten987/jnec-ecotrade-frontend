import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../controllers/home_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  final _homeController = Get.find<HomeController>();

  List<dynamic> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAndMarkAll();
  }

  Future<void> _loadAndMarkAll() async {
    await _loadNotifications();
    if (_notifications.isNotEmpty) {
      await _markAllRead();
    }
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/notifications'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() => _notifications = jsonDecode(response.body));
        _homeController.loadUnreadCount();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load notifications: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _markAllRead() async {
    try {
      final token = await _getToken();
      await http.put(
        Uri.parse('${Constants.baseUrl}/notifications/read-all'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      _homeController.unreadCount.value = 0;
      setState(() {
        _notifications = _notifications
            .map((n) => {...n, 'is_read': true})
            .toList();
      });
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  Future<void> _clearAll() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All'),
        content: const Text(
            'Are you sure you want to remove all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token    = await _getToken();
        final response = await http.delete(
          Uri.parse('${Constants.baseUrl}/notifications/clear'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          setState(() => _notifications = []);
          _homeController.unreadCount.value = 0;
          Get.snackbar('Cleared', 'All notifications cleared!',
              backgroundColor: Colors.teal.shade600,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        }
      } catch (e) {
        Get.snackbar('Error', 'Error: $e',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  // ✅ Open WhatsApp with pre-filled message to seller
  Future<void> _contactSellerWhatsApp({
    required String phone,
    required String itemName,
    required String bidPrice,
  }) async {
    // Clean phone number and add Bhutan country code
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!cleaned.startsWith('975')) {
      cleaned = '975$cleaned';
    }

    final message = Uri.encodeComponent(
      'Hi! 🎉 I won the auction for "$itemName" '
      'with a bid of Nu. $bidPrice on JNEC Eco-Trade (ReDruk). '
      'Can we arrange the exchange?',
    );

    final url = 'https://wa.me/$cleaned?text=$message';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'Cannot Open WhatsApp',
        phone.isEmpty
            ? 'Seller has no contact number listed.'
            : 'Could not open WhatsApp. Make sure it is installed.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ✅ Parse bid price from notification message
  // Message format: "Your bid of Nu. 500 won the auction for "Item"!"
  String _extractBidPrice(String message) {
    final regex = RegExp(r'Nu\.\s*([\d.]+)');
    final match = regex.firstMatch(message);
    return match?.group(1) ?? '';
  }

  // ✅ Parse item name from notification message
  // Message format: '...won the auction for "Item Name"!'
  String _extractItemName(String message) {
    final regex = RegExp(r'"([^"]+)"');
    final match = regex.firstMatch(message);
    return match?.group(1) ?? '';
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'posted':        return Icons.upload_outlined;
      case 'booked':        return Icons.bookmark_outlined;
      case 'approved':      return Icons.check_circle_outline;
      case 'cancelled':     return Icons.cancel_outlined;
      case 'new_item':      return Icons.new_releases_outlined;
      case 'auction':       return Icons.gavel;
      case 'auction_won':   return Icons.emoji_events;
      case 'auction_lost':  return Icons.sentiment_dissatisfied_outlined;
      case 'auction_closed':return Icons.gavel;
      default:              return Icons.notifications_outlined;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'posted':         return Colors.teal.shade600;
      case 'booked':         return Colors.blue.shade600;
      case 'approved':       return Colors.green.shade600;
      case 'cancelled':      return Colors.red.shade600;
      case 'new_item':       return Colors.orange.shade600;
      case 'auction':        return Colors.teal.shade600;
      case 'auction_won':    return Colors.amber.shade700;
      case 'auction_lost':   return Colors.red.shade400;
      case 'auction_closed': return Colors.indigo.shade600;
      default:               return Colors.grey.shade600;
    }
  }

  Color _getBackgroundColor(String type, bool isRead) {
    if (type == 'auction_won') return Colors.amber.shade50;
    if (type == 'auction_lost') return Colors.red.shade50;
    if (!isRead) return Colors.teal.shade50;
    return Colors.white;
  }

  Color _getBorderColor(String type, bool isRead) {
    if (type == 'auction_won') return Colors.amber.shade300;
    if (type == 'auction_lost') return Colors.red.shade200;
    if (!isRead) return Colors.teal.shade100;
    return Colors.grey.shade200;
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndMarkAll,
          ),
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.teal))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAndMarkAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif  = _notifications[index];
                      final isRead = notif['is_read'] == true ||
                          notif['is_read'] == 1;
                      final type    = notif['type'] ?? 'general';
                      final title   = notif['title'] ?? '';
                      final message = notif['message'] ?? '';

                      // ✅ Special card for auction_won
                      if (type == 'auction_won') {
                        return _buildAuctionWonCard(
                          notif: notif,
                          isRead: isRead,
                          title: title,
                          message: message,
                        );
                      }

                      // ✅ Special card for auction_lost
                      if (type == 'auction_lost') {
                        return _buildAuctionLostCard(
                          notif: notif,
                          isRead: isRead,
                          title: title,
                          message: message,
                        );
                      }

                      // ✅ Special card for auction_closed (seller)
                      if (type == 'auction_closed') {
                        return _buildAuctionClosedCard(
                          notif: notif,
                          isRead: isRead,
                          title: title,
                          message: message,
                        );
                      }

                      // ── Default notification card ──
                      return _buildDefaultCard(
                        notif: notif,
                        isRead: isRead,
                        type: type,
                        title: title,
                        message: message,
                      );
                    },
                  ),
                ),
    );
  }

  // ✅ AUCTION WON card — gold, with WhatsApp button to contact seller
  Widget _buildAuctionWonCard({
    required dynamic notif,
    required bool isRead,
    required String title,
    required String message,
  }) {
    final itemName = _extractItemName(message);
    final bidPrice = _extractBidPrice(message);
    // ✅ Try to get seller phone from notification metadata
    // Backend should include seller_phone in message or as extra field
    final sellerPhone = notif['seller_phone']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header row ──
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      Text(
                        _timeAgo(notif['created_at']),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.amber, shape: BoxShape.circle),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Message ──
            Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),

            const SizedBox(height: 14),
            Divider(color: Colors.amber.shade200),
            const SizedBox(height: 10),

            // ── Info box ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Next Step',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contact the seller on WhatsApp to arrange the item exchange.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ✅ WhatsApp button — contacts seller
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // ✅ If seller_phone is in notification data, use it directly
                  if (sellerPhone.isNotEmpty) {
                    await _contactSellerWhatsApp(
                      phone: sellerPhone,
                      itemName: itemName,
                      bidPrice: bidPrice,
                    );
                  } else {
                    // ✅ Fallback: fetch from my-bookings to get seller contact
                    Get.dialog(
                      const Center(child: CircularProgressIndicator()),
                      barrierDismissible: false,
                    );
                    final contact = await _fetchSellerContactFromBookings(itemName);
                    Get.back(); // close loading
                    await _contactSellerWhatsApp(
                      phone: contact['phone'] ?? '',
                      itemName: itemName,
                      bidPrice: bidPrice,
                    );
                  }
                },
                icon: const Icon(Icons.chat, color: Colors.white, size: 20),
                label: const Text(
                  'Contact Seller on WhatsApp',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp green
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ AUCTION LOST card — red tint, sympathetic message
  Widget _buildAuctionLostCard({
    required dynamic notif,
    required bool isRead,
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sentiment_dissatisfied_outlined,
                color: Colors.red.shade600, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700)),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(_timeAgo(notif['created_at']),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: Colors.red.shade400, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  // ✅ AUCTION CLOSED card — for seller (their item was sold)
  Widget _buildAuctionClosedCard({
    required dynamic notif,
    required bool isRead,
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.gavel,
                color: Colors.indigo.shade600, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700)),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(_timeAgo(notif['created_at']),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    '💡 The winner has been notified to contact you.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.indigo.shade700),
                  ),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: Colors.indigo.shade400,
                  shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  // ── Default notification card (unchanged style) ──
  Widget _buildDefaultCard({
    required dynamic notif,
    required bool isRead,
    required String type,
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(type, isRead),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor(type, isRead)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _getColor(type).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIcon(type), color: _getColor(type), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(_timeAgo(notif['created_at']),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: Colors.teal.shade600, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  // ✅ Fetch seller contact from my-bookings (confirmed auction booking)
  Future<Map<String, String>> _fetchSellerContactFromBookings(
      String itemName) async {
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/my-bookings'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> bookings = jsonDecode(response.body);
        // ✅ Find the confirmed auction booking for this item
        final booking = bookings.firstWhereOrNull((b) {
          final bItem  = b['item'] ?? {};
          final bName  = bItem['item_name']?.toString() ?? '';
          final status = b['status']?.toString() ?? '';
          final auctionEnabled = bItem['auction_enabled'];
          final isAuction = auctionEnabled == true ||
              auctionEnabled == 1 ||
              auctionEnabled.toString() == 'true';
          return isAuction &&
              status == 'confirmed' &&
              bName.toLowerCase().contains(itemName.toLowerCase());
        });

        if (booking != null) {
          final item   = booking['item'] ?? {};
          final seller = item['user'] ?? {};
          return {
            'phone':  item['contact_preference']?.toString() ?? '',
            'seller': seller['name']?.toString() ?? 'Seller',
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching booking: $e');
    }
    return {'phone': '', 'seller': 'Seller'};
  }
}