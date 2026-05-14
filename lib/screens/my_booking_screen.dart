import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import 'item_detail_screen.dart';

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends State<MyBookingScreen> {
  List<dynamic> _bookings = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
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
        setState(() => _bookings = jsonDecode(response.body));
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load bookings: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _removeBooking(int bookingId, String status) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Booking'),
        content: Text(
          status == 'confirmed'
              ? 'This booking was approved. Are you sure you want to remove it from your list?'
              : 'Are you sure you want to remove this booking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _getToken();

      if (status == 'pending') {
        // Step 1: Cancel
        await http.put(
          Uri.parse('${Constants.baseUrl}/bookings/$bookingId/cancel'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        // Step 2: Delete from list
        final deleteResponse = await http.delete(
          Uri.parse('${Constants.baseUrl}/bookings/$bookingId/delete'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (deleteResponse.statusCode == 200) {
          Get.snackbar('Removed', 'Booking removed successfully!',
              backgroundColor: Colors.teal.shade600,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
          _loadBookings();
        } else {
          final data = jsonDecode(deleteResponse.body);
          Get.snackbar('Error', data['message'] ?? 'Failed!',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        // Confirmed/Cancelled: just DELETE from list
        final deleteResponse = await http.delete(
          Uri.parse('${Constants.baseUrl}/bookings/$bookingId/delete'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (deleteResponse.statusCode == 200) {
          Get.snackbar('Removed', 'Booking removed successfully!',
              backgroundColor: Colors.teal.shade600,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
          _loadBookings();
        } else {
          final data = jsonDecode(deleteResponse.body);
          Get.snackbar('Error', data['message'] ?? 'Failed!',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _contactSeller(dynamic item) async {
    final contact = item['contact_preference'] ?? '';
    String phone  = contact.replaceAll(RegExp(r'[^\d]'), '');
    if (!phone.startsWith('975')) phone = '975$phone';

    final itemName = item['item_name'] ?? 'item';
    final price    = item['price'] ?? '';
    final message  = Uri.encodeComponent(
      'Hi! I booked your "$itemName" listed for Nu. $price on JNEC Eco-trade. Can we proceed?',
    );

    final whatsappUrl = 'https://wa.me/$phone?text=$message';

    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'Error',
        contact.isEmpty ? 'No contact number available!' : 'Could not open WhatsApp!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ✅ Helper: check if item is an auction item
  bool _isAuction(dynamic item) {
    final val = item['auction_enabled'];
    return val == true || val == 1 || val.toString() == 'true';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green.shade600;
      case 'cancelled': return Colors.red.shade600;
      default:          return Colors.orange.shade600;
    }
  }

  String _statusLabel(String status, bool isAuction) {
    if (isAuction) {
      switch (status) {
        case 'confirmed': return '🏆 Auction Won!';
        case 'cancelled': return 'Outbid';
        default:          return 'Bidding...';
      }
    }
    switch (status) {
      case 'confirmed': return 'Approved ✅';
      case 'cancelled': return 'Cancelled';
      default:          return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('My Booking',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.teal))
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border_outlined,
                          size: 70, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No bookings yet',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Book items from the home screen',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final booking   = _bookings[index];
                      final item      = booking['item'] ?? {};
                      final status    = booking['status'] ?? 'pending';
                      final isAuction = _isAuction(item);
                      final bidPrice  = double.tryParse(
                              booking['bid_price']?.toString() ?? '0') ??
                          0.0;

                      // ✅ Won the auction
                      final isWinner =
                          isAuction && status == 'confirmed';
                      // ✅ Lost the auction
                      final isLost =
                          isAuction && status == 'cancelled';

                      Uint8List? imageBytes;
                      if (item['image'] != null &&
                          item['image'].toString().isNotEmpty) {
                        try {
                          imageBytes = base64Decode(item['image']);
                        } catch (_) {}
                      }

                      return GestureDetector(
                        onTap: () =>
                            Get.to(() => ItemDetailScreen(item: item)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            // ✅ Gold border for auction winner
                            border: Border.all(
                              color: isWinner
                                  ? Colors.amber.shade400
                                  : isLost
                                      ? Colors.red.shade200
                                      : Colors.grey.shade200,
                              width: isWinner ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                // ── Image ──
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: imageBytes != null
                                        ? Image.memory(imageBytes,
                                            fit: BoxFit.cover)
                                        : Container(
                                            color: Colors.grey.shade100,
                                            child: Icon(Icons.image_outlined,
                                                size: 30,
                                                color: Colors.grey.shade300),
                                          ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // ── Info ──
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [

                                      // ✅ Auction badge if applicable
                                      if (isAuction) ...[
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isWinner
                                                    ? Colors.amber.shade600
                                                    : Colors.teal.shade600,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isWinner
                                                        ? Icons.emoji_events
                                                        : Icons.gavel,
                                                    color: Colors.white,
                                                    size: 10,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isWinner
                                                        ? 'WON'
                                                        : 'AUCTION',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],

                                      // Item name
                                      Text(
                                        item['item_name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),

                                      // ✅ Show bid price for auctions
                                      if (isAuction && bidPrice > 0)
                                        Text(
                                          'Your bid: Nu. ${bidPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.teal.shade700,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      else
                                        Text(
                                          'Nu. ${item['price'] ?? ''}',
                                          style: TextStyle(
                                            color: Colors.teal.shade600,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),

                                      const SizedBox(height: 6),

                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: _statusColor(status)
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          _statusLabel(status, isAuction),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // ── Buttons ──
                                      Row(
                                        children: [

                                          // ✅ Contact seller via WhatsApp:
                                          //    - Normal booking: always show if not confirmed
                                          //    - Auction: ONLY show if WON (confirmed)
                                          //    - Auction lost: hide completely
                                          if (!isAuction && status != 'confirmed') ...[
                                            Expanded(
                                              child: SizedBox(
                                                height: 30,
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _contactSeller(item),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.teal.shade600,
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20)),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  child: const Text('Contact',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],

                                          // ✅ Auction winner — show contact seller button
                                          if (isWinner) ...[
                                            Expanded(
                                              child: SizedBox(
                                                height: 30,
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _contactSeller(item),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.amber.shade600,
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20)),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  child: const Text(
                                                      'Contact Seller',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],

                                          // Remove button — always visible
                                          Expanded(
                                            child: SizedBox(
                                              height: 30,
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    _removeBooking(
                                                        booking['id'], status),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20)),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: const Text('Remove',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}