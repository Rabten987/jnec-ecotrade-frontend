import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import 'edit_item_screen.dart';
import 'notifications_screen.dart';

/// ✅ Tab content for "My Listings" — used inside MainNavScreen's PageView.
/// Has its own AppBar (Scaffold's appBar lives in MainNavScreen, this is
/// rendered as the page content with its own internal AppBar-like header).
class MyListingItemsTab extends StatefulWidget {
  const MyListingItemsTab({super.key});

  @override
  State<MyListingItemsTab> createState() => MyListingItemsTabState();
}

class MyListingItemsTabState extends State<MyListingItemsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ✅ Preserve state when swiped away from

  List<dynamic> _myItems = [];
  bool _isLoading        = false;

  @override
  void initState() {
    super.initState();
    _loadMyItems();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadMyItems() async {
    setState(() => _isLoading = true);
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/my-items'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        setState(() => _myItems = jsonDecode(response.body));
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load items: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteItem(int id) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final token    = await _getToken();
      final response = await http.delete(
        Uri.parse('${Constants.baseUrl}/items/$id'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        Get.snackbar('Deleted', 'Item deleted successfully!',
            backgroundColor: Colors.teal.shade600, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
        _loadMyItems();
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available': return Colors.green.shade600;
      case 'booked':    return Colors.orange.shade600;
      case 'sold':      return Colors.red.shade600;
      default:          return Colors.grey.shade600;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available': return 'Available';
      case 'booked':    return 'Booked';
      case 'sold':      return 'Sold';
      default:          return status;
    }
  }

  String _timeLeft(String? endsAt) {
    if (endsAt == null) return '';
    try {
      final end  = DateTime.parse(endsAt).toLocal();
      final now  = DateTime.now();
      if (now.isAfter(end)) return 'Ended';
      final diff = end.difference(now);
      if (diff.inDays > 0)  return '${diff.inDays}d left';
      if (diff.inHours > 0) return '${diff.inHours}h left';
      return '${diff.inMinutes}m left';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('My Listing',
            style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMyItems),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Get.to(() => const NotificationsScreen()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _myItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No items posted yet',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Start posting items to sell!',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMyItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _myItems.length,
                    itemBuilder: (context, index) =>
                        _buildItemCard(_myItems[index]),
                  ),
                ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    final Uint8List? imageBytes = ImageHelper.getFirstImage(item['image']);

    final status    = item['status'] ?? 'available';
    final isSold    = status == 'sold';
    final isAuction = item['auction_enabled'] == true ||
        item['auction_enabled'] == 1 ||
        item['auction_enabled'].toString() == 'true';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAuction ? Colors.teal.shade300 : Colors.grey.shade200,
          width: isAuction ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── Image fixed 85x100 ──
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: SizedBox(
              width: 85, height: 100,
              child: imageBytes != null
                  ? Image.memory(imageBytes, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade100,
                      child: Icon(Icons.image_outlined,
                          color: Colors.grey.shade300, size: 30)),
            ),
          ),

          // ── Info ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Name + badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(item['item_name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isAuction)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('Auction',
                              style: TextStyle(fontSize: 9,
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // Price
                  Text('Nu. ${item['price']}',
                      style: TextStyle(color: Colors.teal.shade600,
                          fontSize: 12, fontWeight: FontWeight.w600)),

                  const SizedBox(height: 3),

                  // Status row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(_getStatusLabel(status),
                            style: TextStyle(fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(status))),
                      ),
                      if (isAuction && item['auction_ends_at'] != null) ...[
                        const SizedBox(width: 5),
                        Text(_timeLeft(item['auction_ends_at']),
                            style: TextStyle(fontSize: 9,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500)),
                      ],
                      if (isAuction && item['min_bid_price'] != null) ...[
                        const SizedBox(width: 5),
                        Text('Min: Nu.${item['min_bid_price']}',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 26,
                          child: ElevatedButton(
                            onPressed: isSold ? null : () async {
                              await Get.to(() => EditItemScreen(item: item));
                              _loadMyItems();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSold
                                  ? Colors.grey.shade400
                                  : Colors.teal.shade600,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Edit',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 26,
                          child: ElevatedButton(
                            onPressed: () => _deleteItem(item['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}