import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'edit_item_screen.dart';
import 'notifications_screen.dart';

class MyListingItemsScreen extends StatefulWidget {
  const MyListingItemsScreen({super.key});

  @override
  State<MyListingItemsScreen> createState() => _MyListingItemsScreenState();
}

class _MyListingItemsScreenState extends State<MyListingItemsScreen> {
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

  Future<void> _editAuction(dynamic item) async {
    final minBidController = TextEditingController(
        text: item['min_bid_price']?.toString() ?? '');
    final daysController   = TextEditingController();
    String _action         = 'extend'; // ✅ dropdown state

    String currentTimeLeft = '';
    if (item['auction_ends_at'] != null) {
      try {
        final end  = DateTime.parse(item['auction_ends_at']).toLocal();
        final now  = DateTime.now();
        final diff = end.difference(now);
        currentTimeLeft = diff.isNegative
            ? 'Auction already ended'
            : '${diff.inDays}d ${diff.inHours.remainder(24)}h remaining';
      } catch (_) {}
    }

    await Get.dialog(
      StatefulBuilder( // ✅ allows dropdown to update inside dialog
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.gavel, color: Colors.teal.shade600, size: 20),
              const SizedBox(width: 8),
              const Text('Edit Auction'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              if (currentTimeLeft.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Current: $currentTimeLeft',
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade700)),
                ),

              TextField(
                controller: minBidController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Min Bid Price (Nu)',
                  labelStyle: TextStyle(color: Colors.teal.shade600),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade300)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade600)),
                ),
              ),

              const SizedBox(height: 16),

              // ✅ Dropdown — Extend or Reduce
              DropdownButtonFormField<String>(
                value: _action,
                decoration: InputDecoration(
                  labelText: 'Action',
                  labelStyle: TextStyle(color: Colors.teal.shade600),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade300)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade600)),
                ),
                items: const [
                  DropdownMenuItem(value: 'extend', child: Text('⏩ Extend auction')),
                  DropdownMenuItem(value: 'reduce', child: Text('⏪ Reduce auction')),
                ],
                onChanged: (val) => setDialogState(() => _action = val!),
              ),

              const SizedBox(height: 12),

              // ✅ Days input
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _action == 'extend'
                      ? 'Extend by how many days?'
                      : 'Reduce by how many days?',
                  hintText: 'e.g. 3',
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
                  labelStyle: TextStyle(color: Colors.teal.shade600),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade300)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade600)),
                ),
              ),

              const SizedBox(height: 6),
              Text(
                _action == 'extend'
                    ? 'Auction end date will be pushed forward.'
                    : 'Auction end date will be moved closer.',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                final token = await _getToken();
                final body  = <String, dynamic>{
                  'item_name':          item['item_name'],
                  'condition':          item['condition'],
                  'category':           item['category'],
                  'price':              item['price'],
                  'location':           item['location'] ?? '',
                  'contact_preference': item['contact_preference'] ?? '',
                };
                if (minBidController.text.isNotEmpty) {
                  body['min_bid_price'] = double.parse(minBidController.text);
                }
                if (daysController.text.isNotEmpty) {
                  final days = int.parse(daysController.text);
                  // ✅ Calculate new end date based on action
                  DateTime currentEnd = DateTime.now();
                  if (item['auction_ends_at'] != null) {
                    try {
                      final parsed = DateTime.parse(item['auction_ends_at']).toLocal();
                      if (parsed.isAfter(DateTime.now())) currentEnd = parsed;
                    } catch (_) {}
                  }
                  final newEnd = _action == 'extend'
                      ? currentEnd.add(Duration(days: days))
                      : currentEnd.subtract(Duration(days: days));
                  // Send as days from now
                  final daysFromNow = newEnd.difference(DateTime.now()).inDays;
                  body['auction_duration'] = daysFromNow < 1 ? 1 : daysFromNow;
                }
                final response = await http.put(
                  Uri.parse('${Constants.baseUrl}/items/${item['id']}'),
                  headers: {
                    'Content-Type':  'application/json',
                    'Accept':        'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode(body),
                );
                if (response.statusCode == 200) {
                  Get.snackbar('Updated', 'Auction settings updated!',
                      backgroundColor: Colors.teal.shade600, colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                  _loadMyItems();
                } else {
                  Get.snackbar('Error', 'Failed to update!',
                      backgroundColor: Colors.red, colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    minBidController.dispose();
    daysController.dispose();
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
      if (diff.inDays > 0) return '${diff.inDays}d left';
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
        title: const Text('My Listing', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
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
                      Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade300),
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
                    itemBuilder: (context, index) => _buildItemCard(_myItems[index]),
                  ),
                ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    Uint8List? imageBytes;
    if (item['image'] != null && item['image'].toString().isNotEmpty) {
      try { imageBytes = base64Decode(item['image']); } catch (_) {}
    }

    final status    = item['status'] ?? 'available';
    final isSold    = status == 'sold';
    final isAuction = item['auction_enabled'] == true || item['auction_enabled'] == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Image ──
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: SizedBox(
              width: 100, height: 120,
              child: imageBytes != null
                  ? Image.memory(imageBytes, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade100,
                      child: Icon(Icons.image_outlined, color: Colors.grey.shade300, size: 36)),
            ),
          ),

          // ── Info ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Name + auction badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(item['item_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isAuction)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('🏷 Auction',
                              style: TextStyle(fontSize: 9,
                                  color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Price
                  Text('Nu. ${item['price']}',
                      style: TextStyle(
                          color: Colors.teal.shade600, fontSize: 13, fontWeight: FontWeight.w600)),

                  const SizedBox(height: 4),

                  // Status + auction time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(_getStatusLabel(status),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: _getStatusColor(status))),
                      ),
                      if (isAuction && item['auction_ends_at'] != null) ...[
                        const SizedBox(width: 6),
                        Text(_timeLeft(item['auction_ends_at']),
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),

                  if (isAuction && item['min_bid_price'] != null) ...[
                    const SizedBox(height: 2),
                    Text('Min bid: Nu. ${item['min_bid_price']}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],

                  const SizedBox(height: 8),

                  // ── Buttons ──
                  Row(
                    children: [

                      // Edit button
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: isSold ? null : () async {
                              await Get.to(() => EditItemScreen(item: item));
                              _loadMyItems();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSold ? Colors.grey.shade400 : Colors.teal.shade600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Edit',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // ✅ Auction button — only for auction items
                      if (isAuction) ...[
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: isSold ? null : () => _editAuction(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSold ? Colors.grey.shade400 : Colors.amber.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('Auction',
                                  style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Delete button
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => _deleteItem(item['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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