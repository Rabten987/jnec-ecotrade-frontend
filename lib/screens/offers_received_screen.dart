import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import 'item_bids_screen.dart';
import 'app_bottom_nav.dart';

/// ✅ First-level screen — shows ALL auction items posted by the seller
/// that have received at least one bid. Tapping an item opens
/// ItemBidsScreen showing all bids placed on that specific item.
class OffersReceivedScreen extends StatefulWidget {
  const OffersReceivedScreen({super.key});

  @override
  State<OffersReceivedScreen> createState() => _OffersReceivedScreenState();
}

class _OffersReceivedScreenState extends State<OffersReceivedScreen> {
  List<dynamic> _groupedItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/booking-requests'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _groupedItems = _groupByItem(data);
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load offers: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  /// ✅ Groups flat booking list by item_id.
  /// Only includes items that have at least 1 bid.
  List<dynamic> _groupByItem(List<dynamic> requests) {
    final Map<int, Map<String, dynamic>> grouped = {};

    for (final booking in requests) {
      final item   = booking['item'] ?? {};
      final itemId = item['id'] as int?;
      if (itemId == null) continue;

      if (!grouped.containsKey(itemId)) {
        grouped[itemId] = {
          'item':         item,
          'bids':         <dynamic>[],
          'pendingCount': 0,
          'highestBid':   0.0,
          'hasWinner':    false,
        };
      }

      final bidPrice = double.tryParse(
              booking['bid_price']?.toString() ?? '0') ?? 0.0;
      final status = booking['status'] ?? 'pending';

      grouped[itemId]!['bids'].add(booking);

      if (status == 'pending') {
        grouped[itemId]!['pendingCount'] =
            (grouped[itemId]!['pendingCount'] as int) + 1;
      }
      if (status == 'confirmed') {
        grouped[itemId]!['hasWinner'] = true;
      }
      if (bidPrice > (grouped[itemId]!['highestBid'] as double)) {
        grouped[itemId]!['highestBid'] = bidPrice;
      }
    }

    // ✅ Only items with at least 1 bid (guaranteed since we built from bookings)
    final result = grouped.values.toList();

    // ✅ Sort: items with pending bids first, then by bid count
    result.sort((a, b) {
      final aPending = a['pendingCount'] as int;
      final bPending = b['pendingCount'] as int;
      if (aPending != bPending) return bPending.compareTo(aPending);
      return (b['bids'] as List).length.compareTo((a['bids'] as List).length);
    });

    return result;
  }

  String _timeLeft(dynamic item) {
    if (item['auction_ends_at'] == null) return '';
    try {
      final endsAt = DateTime.parse(item['auction_ends_at']).toLocal();
      final now    = DateTime.now();
      if (now.isAfter(endsAt)) return 'Ended';
      final diff = endsAt.difference(now);
      if (diff.inDays > 0)  return '${diff.inDays}d left';
      if (diff.inHours > 0) return '${diff.inHours}h left';
      return '${diff.inMinutes}m left';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('Offers Received',
            style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
        ],
      ),
      body: SwipeNavWrapper(
        currentIndex: 3,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : _groupedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gavel, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No offers yet',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Bids on your items will appear here',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedItems.length,
                    itemBuilder: (context, index) {
                      final group       = _groupedItems[index];
                      final item        = group['item'];
                      final bids        = group['bids'] as List;
                      final pendingCount= group['pendingCount'] as int;
                      final highestBid  = group['highestBid'] as double;
                      final hasWinner   = group['hasWinner'] as bool;
                      final timeLeft    = _timeLeft(item);

                      final Uint8List? imageBytes =
                          ImageHelper.getFirstImage(item['image']);

                      return GestureDetector(
                        onTap: () async {
                          await Get.to(() => ItemBidsScreen(
                                item: item,
                                bids: List<dynamic>.from(bids),
                              ));
                          _loadRequests();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasWinner
                                  ? Colors.amber.shade300
                                  : pendingCount > 0
                                      ? Colors.teal.shade300
                                      : Colors.grey.shade200,
                              width: hasWinner || pendingCount > 0 ? 1.5 : 1,
                            ),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [

                              // ── Image ──
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 70, height: 70,
                                  child: imageBytes != null
                                      ? Image.memory(imageBytes, fit: BoxFit.cover)
                                      : Container(
                                          color: Colors.grey.shade100,
                                          child: Icon(Icons.image_outlined,
                                              color: Colors.grey.shade300)),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // ── Info ──
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['item_name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(
                                      highestBid > 0
                                          ? 'Highest bid: Nu. ${highestBid.toStringAsFixed(2)}'
                                          : 'Nu. ${item['price'] ?? ''}',
                                      style: TextStyle(
                                          color: Colors.teal.shade700,
                                          fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        // ✅ Bid count badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(20)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.gavel,
                                                  size: 11, color: Colors.teal.shade700),
                                              const SizedBox(width: 4),
                                              Text('${bids.length} bid${bids.length == 1 ? '' : 's'}',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.teal.shade700,
                                                      fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (hasWinner)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius: BorderRadius.circular(20)),
                                            child: Text('Sold',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.amber.shade800,
                                                    fontWeight: FontWeight.bold)),
                                          )
                                        else if (pendingCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(20)),
                                            child: Text('$pendingCount pending',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange.shade700,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    if (timeLeft.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(timeLeft,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: timeLeft == 'Ended'
                                                  ? Colors.red
                                                  : Colors.grey.shade500,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ],
                                ),
                              ),

                              Icon(Icons.chevron_right, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}