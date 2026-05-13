import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../controllers/auth_controller.dart';

class AuctionScreen extends StatefulWidget {
  final dynamic item;
  const AuctionScreen({super.key, required this.item});

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  final _authController = Get.find<AuthController>();

  List<dynamic> _bids        = [];
  dynamic       _myBid;
  dynamic       _highestBid;
  bool          _isLoading   = false;
  bool          _isPlacing   = false;
  String?       _auctionEndsAt;
  double?       _minBidPrice;

  final _bidController = TextEditingController();

  // ✅ Check if current user is the item owner
  bool get _isOwner {
    final currentEmail = _authController.userEmail.value;
    final sellerEmail  = widget.item['user'] != null
        ? widget.item['user']['email'] ?? ''
        : '';
    return currentEmail == sellerEmail;
  }

  @override
  void initState() {
    super.initState();
    _loadBids();
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadBids() async {
    setState(() => _isLoading = true);
    try {
      final token    = await _getToken();
      final itemId   = widget.item['id'];
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/items/$itemId/bids'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _bids          = data['bids'] ?? [];
          _myBid         = data['my_bid'];
          _highestBid    = data['highest_bid'];
          _auctionEndsAt = data['auction_ends_at'];
          _minBidPrice   = data['min_bid_price'] != null
              ? double.tryParse(data['min_bid_price'].toString())
              : null;
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load bids: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _placeBid() async {
    final bidText = _bidController.text.trim();
    if (bidText.isEmpty) {
      Get.snackbar('Error', 'Please enter a bid amount!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final bidAmount = double.tryParse(bidText);
    if (bidAmount == null || bidAmount <= 0) {
      Get.snackbar('Error', 'Please enter a valid amount!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _isPlacing = true);
    try {
      final token  = await _getToken();
      final itemId = widget.item['id'];
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/items/$itemId/bids'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'bid_price': bidAmount}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        _bidController.clear();
        Get.snackbar('Bid Placed! ✅', data['message'] ?? 'Your bid was placed!',
            backgroundColor: Colors.teal.shade600, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
        _loadBids();
      } else {
        Get.snackbar('Error', data['message'] ?? 'Failed to place bid!',
            backgroundColor: Colors.red, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isPlacing = false);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) { return dateStr; }
  }

  String _timeLeft() {
    if (_auctionEndsAt == null) return '';
    try {
      final endsAt = DateTime.parse(_auctionEndsAt!).toLocal();
      final now    = DateTime.now();
      if (now.isAfter(endsAt)) return 'Auction ended';
      final diff   = endsAt.difference(now);
      if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h left';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
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
        title: const Text('Auction Bids', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBids),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: _loadBids,
              child: Column(
                children: [

                  // ── Auction Info Banner — same teal color ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.teal.shade600, // ✅ same color as before
                    child: Column(
                      children: [
                        Text(
                          widget.item['item_name'] ?? '',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Min Bid',
                                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(
                                  _minBidPrice != null
                                      ? 'Nu. ${_minBidPrice!.toStringAsFixed(0)}'
                                      : 'No min',
                                  style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Highest Bid',
                                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(
                                  _highestBid != null
                                      ? 'Nu. ${_highestBid['bid_price']}'
                                      : 'No bids yet',
                                  style: const TextStyle(color: Colors.yellow,
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Time Left',
                                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(_timeLeft(),
                                    style: const TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── My Current Bid — buyers only ──
                  if (_myBid != null && !_isOwner)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.how_to_reg, color: Colors.teal.shade600),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Your Current Bid',
                                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Text('Nu. ${_myBid['bid_price']}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade700)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _myBid['status'] == 'won'
                                  ? Colors.green
                                  : _myBid['status'] == 'lost'
                                      ? Colors.red
                                      : Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _myBid['status'] == 'won'
                                  ? '🏆 Won'
                                  : _myBid['status'] == 'lost'
                                      ? 'Lost'
                                      : 'Active',
                              style: const TextStyle(color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ✅ Place Bid Input — HIDDEN for seller
                  if (!_isOwner)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _bidController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _myBid != null
                                    ? 'Update your bid (Nu)'
                                    : 'Enter your bid (Nu)',
                                labelStyle: const TextStyle(color: Colors.black54),
                                hintText: _minBidPrice != null
                                    ? 'Min: Nu. ${_minBidPrice!.toStringAsFixed(0)}'
                                    : 'Enter amount',
                                hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _isPlacing ? null : _placeBid,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade600,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              child: _isPlacing
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Text(_myBid != null ? 'Update' : 'Bid',
                                      style: const TextStyle(color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ✅ Seller info box — same white style as bid input
                  if (_isOwner)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.teal.shade600, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You are the seller. You can view all bids but cannot place a bid on your own item.',
                              style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ── Bids List ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('All Bids (${_bids.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Text('Highest first',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: _bids.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.gavel, size: 56, color: Colors.grey.shade300),
                                const SizedBox(height: 10),
                                Text(
                                  _isOwner
                                      ? 'No bids yet on your item'
                                      : 'No bids yet — be the first!',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _bids.length,
                            itemBuilder: (context, index) {
                              final bid       = _bids[index];
                              final isHighest = index == 0;
                              final isMine    = bid['is_mine'] == true;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMine ? Colors.teal.shade50 : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isHighest
                                        ? Colors.amber.shade400
                                        : isMine
                                            ? Colors.teal.shade200
                                            : Colors.grey.shade200,
                                    width: isHighest ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: isHighest ? Colors.amber : Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: isHighest
                                            ? const Text('🏆', style: TextStyle(fontSize: 16))
                                            : Text('${index + 1}',
                                                style: TextStyle(fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade600, fontSize: 12)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isMine ? 'You' : bid['user']?['name'] ?? 'Bidder',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 13,
                                              color: isMine
                                                  ? Colors.teal.shade700
                                                  : Colors.black87,
                                            ),
                                          ),
                                          // ✅ Show email to owner only
                                          if (_isOwner && bid['user']?['email'] != null)
                                            Text(bid['user']['email'],
                                                style: TextStyle(fontSize: 10,
                                                    color: Colors.grey.shade500)),
                                          Text(_formatDate(bid['updated_at']),
                                              style: TextStyle(fontSize: 11,
                                                  color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    Text('Nu. ${bid['bid_price']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 15,
                                          color: isHighest
                                              ? Colors.amber.shade700
                                              : Colors.teal.shade600,
                                        )),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}