import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() =>
      _BookingRequestsScreenState();
}

class _BookingRequestsScreenState
    extends State<BookingRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/booking-requests'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(response.body);
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load requests: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _acceptBooking(int id) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Booking'),
        content: const Text(
            'Are you sure you want to accept this booking? All other requests for this item will be rejected.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Accept',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateBooking(id, 'accept');
    }
  }

  Future<void> _rejectBooking(int id) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Booking'),
        content: const Text(
            'Are you sure you want to reject this booking request?'),
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
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateBooking(id, 'reject');
    }
  }

  Future<void> _updateBooking(int id, String action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.put(
        Uri.parse('${Constants.baseUrl}/bookings/$id/$action'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        Get.snackbar(
          action == 'accept' ? 'Booking Accepted!' : 'Booking Rejected!',
          action == 'accept'
              ? 'Booking accepted. All other requests have been rejected automatically.'
              : 'The booking has been rejected.',
          backgroundColor:
              action == 'accept' ? Colors.teal.shade600 : Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        _loadRequests();
      } else {
        final data = jsonDecode(response.body);
        Get.snackbar('Error', data['message'] ?? 'Failed!',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update booking: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green.shade600;
      case 'cancelled': return Colors.red.shade600;
      default:          return Colors.orange.shade600;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Accepted ✅';
      case 'cancelled': return 'Rejected';
      default:          return 'Pending';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ✅ Helper: check if item is an auction item
  bool _isAuction(dynamic item) {
    final val = item['auction_enabled'];
    return val == true || val == 1 || val.toString() == 'true';
  }

  // ✅ Helper: check if auction has ended
  bool _auctionEnded(dynamic item) {
    if (item['auction_ends_at'] == null) return false;
    try {
      final endsAt = DateTime.parse(item['auction_ends_at']).toUtc();
      return DateTime.now().toUtc().isAfter(endsAt);
    } catch (_) {
      return false;
    }
  }

  // ✅ Helper: format auction time left
  String _timeLeft(dynamic item) {
    if (item['auction_ends_at'] == null) return '';
    try {
      final endsAt = DateTime.parse(item['auction_ends_at']).toLocal();
      final now    = DateTime.now();
      if (now.isAfter(endsAt)) return 'Auction Ended';
      final diff = endsAt.difference(now);
      if (diff.inDays > 0)   return '${diff.inDays}d left';
      if (diff.inHours > 0)  return '${diff.inHours}h left';
      return '${diff.inMinutes}m left';
    } catch (_) {
      return '';
    }
  }

  // ✅ Group requests by item_id so we can find highest bidder per item
  // Returns map of item_id → highest bid_price among confirmed/pending bookings
  Map<int, double> _highestBidPerItem() {
    // We look at auctions field if returned, otherwise use booking order
    // Since backend returns bookings sorted by latest, we check auction status
    final Map<int, double> result = {};
    for (final booking in _requests) {
      final item   = booking['item'] ?? {};
      final itemId = item['id'] as int? ?? 0;
      if (!_isAuction(item)) continue;

      // ✅ Check auction data attached to booking if available
      final bidPrice = double.tryParse(
              booking['bid_price']?.toString() ?? '0') ??
          0.0;
      if (!result.containsKey(itemId) || bidPrice > result[itemId]!) {
        result[itemId] = bidPrice;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Group by item to find highest bidder
    final highestBids = _highestBidPerItem();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'Booking Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.teal))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No booking requests yet',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final booking = _requests[index];
                      final item    = booking['item'] ?? {};
                      final buyer   = booking['user'] ?? {};
                      final status  = booking['status'] ?? 'pending';
                      final isAuction  = _isAuction(item);
                      final ended      = _auctionEnded(item);
                      final timeLeft   = _timeLeft(item);
                      final itemId     = item['id'] as int? ?? 0;

                      // ✅ Bid price for this booking (if auction)
                      final bidPrice = double.tryParse(
                              booking['bid_price']?.toString() ?? '0') ??
                          0.0;

                      // ✅ Is this the highest bidder for this item?
                      final isHighest = isAuction &&
                          highestBids[itemId] != null &&
                          bidPrice > 0 &&
                          bidPrice == highestBids[itemId];

                      Uint8List? imageBytes;
                      if (item['image'] != null &&
                          item['image'].toString().isNotEmpty) {
                        try {
                          imageBytes = base64Decode(item['image']);
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          // ✅ Highlight highest bidder card with teal border
                          border: Border.all(
                            color: isHighest
                                ? Colors.teal.shade400
                                : Colors.grey.shade200,
                            width: isHighest ? 2 : 1,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ── Auction badge row (top) ──
                              if (isAuction) ...[
                                Row(
                                  children: [
                                    // Auction badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.gavel,
                                              color: Colors.white, size: 11),
                                          const SizedBox(width: 4),
                                          const Text('AUCTION',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // ✅ Highest bidder badge
                                    if (isHighest)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade600,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.emoji_events,
                                                color: Colors.white, size: 11),
                                            SizedBox(width: 4),
                                            Text('HIGHEST BID',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),

                                    const Spacer(),

                                    // Time left / ended
                                    Text(
                                      timeLeft,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ended
                                            ? Colors.red
                                            : Colors.orange.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],

                              // ── Item Info Row ──
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 70,
                                      height: 70,
                                      child: imageBytes != null
                                          ? Image.memory(imageBytes,
                                              fit: BoxFit.cover)
                                          : Container(
                                              color: Colors.grey.shade100,
                                              child: Icon(Icons.image_outlined,
                                                  color: Colors.grey.shade300),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['item_name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),

                                        // ✅ Show bid price for auction, regular price for normal
                                        if (isAuction && bidPrice > 0)
                                          Text(
                                            'Bid: Nu. ${bidPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.teal.shade700,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          )
                                        else
                                          Text(
                                            'Nu. ${item['price'] ?? ''}',
                                            style: TextStyle(
                                              color: Colors.teal.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),

                                        const SizedBox(height: 4),

                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _statusColor(status),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              Divider(color: Colors.grey.shade200),
                              const SizedBox(height: 8),

                              // ── Buyer Info ──
                              Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 16, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text('Requested by: ',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13)),
                                  Text(buyer['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Date: ${_formatDate(booking['created_at'])}',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12),
                                  ),
                                ],
                              ),

                              // ── Auction auto-handle notice ──
                              if (isAuction && status == 'pending') ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 15,
                                          color: Colors.blue.shade700),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          ended
                                              ? 'Auction ended — winner is being confirmed automatically.'
                                              : 'Auction in progress — winner will be auto-confirmed when auction ends.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ── Accept / Reject — ONLY for NON-auction pending bookings ──
                              // ✅ For auction items, the scheduler handles this automatically.
                              //    Hiding these buttons prevents the seller from accidentally
                              //    accepting the wrong (non-highest) bidder.
                              if (status == 'pending' && !isAuction) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _acceptBooking(booking['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.teal.shade600,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Accept',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _rejectBooking(booking['id']),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Colors.red),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Reject',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // ✅ Auction confirmed — show winner confirmation message
                              if (isAuction && status == 'confirmed') ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.emoji_events,
                                          size: 15,
                                          color: Colors.green.shade700),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'This buyer won the auction with a bid of Nu. ${bidPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}