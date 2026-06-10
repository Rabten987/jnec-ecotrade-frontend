import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import '../controllers/saved_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import 'auction_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ItemDetailScreen extends StatefulWidget {
  final dynamic item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _savedController = Get.find<SavedController>();
  final _cartController  = Get.find<CartController>();
  final _authController  = Get.find<AuthController>();

  final _isBooking = false.obs;
  final _isBooked  = false.obs;
  int? _bookingId;

  // ✅ Image carousel state
  int _currentImageIndex = 0;

  // ✅ Auction state
  List<dynamic> _bids         = [];
  dynamic       _myBid;
  dynamic       _highestBid;
  String?       _auctionEndsAt;
  bool          _isAuction    = false;
  double?       _minBidPrice;
  bool          _isPlacingBid = false;
  final _bidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auctionVal = widget.item['auction_enabled'];
    _isAuction = auctionVal == true || auctionVal == 1 || auctionVal.toString() == 'true';
    _checkIfBooked();
    if (_isAuction) _loadBids();
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

  // ✅ Get all images using ImageHelper (handles single or JSON array)
  List<Uint8List> get _images => ImageHelper.getImages(widget.item['image']);

  Future<void> _checkIfBooked() async {
    try {
      final token = await _getToken();
      if (token.isEmpty) return;
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/my-bookings'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final bookings = jsonDecode(response.body) as List;
        for (final booking in bookings) {
          if (booking['item'] != null &&
              booking['item']['id'] == widget.item['id'] &&
              booking['status'] == 'pending') {
            _isBooked.value = true;
            _bookingId      = booking['id'];
            break;
          }
        }
      }
    } catch (e) { debugPrint('Check booked error: $e'); }
  }

  Future<void> _loadBids() async {
    try {
      final token  = await _getToken();
      final itemId = widget.item['id'];
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/items/$itemId/bids'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
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
    } catch (e) { debugPrint('Load bids error: $e'); }
  }

  Future<void> _placeBid() async {
    final bidText = _bidController.text.trim();
    if (bidText.isEmpty) {
      Get.snackbar('Error', 'Please enter a bid amount!',
          backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final bidAmount = double.tryParse(bidText);
    if (bidAmount == null || bidAmount <= 0) {
      Get.snackbar('Error', 'Please enter a valid amount!',
          backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _isPlacingBid = true);
    try {
      final token  = await _getToken();
      final itemId = widget.item['id'];
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/items/$itemId/bids'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'bid_price': bidAmount}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        _bidController.clear();
        _isBooked.value = true;
        _bookingId      = data['booking']?['id'];
        Get.snackbar('Bid Placed!', 'Your bid of Nu. $bidAmount was placed!',
            backgroundColor: Colors.teal.shade600, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        _loadBids();
        try { Get.find<HomeController>().loadUnreadCount(); } catch (_) {}
      } else {
        Get.snackbar('Error', data['message'] ?? 'Failed to place bid!',
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isPlacingBid = false);
  }

  Future<void> _cancelBooking() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isAuction ? 'Cancel Bid' : 'Cancel Booking'),
        content: Text(_isAuction ? 'Are you sure you want to cancel your bid?' : 'Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('No', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    _isBooking.value = true;
    try {
      final token  = await _getToken();
      final itemId = widget.item['id'];

      if (_isAuction) {
        final response = await http.delete(
          Uri.parse('${Constants.baseUrl}/items/$itemId/bids'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        );
        _isBooking.value = false;
        if (response.statusCode == 200) {
          _isBooked.value = false;
          _bookingId      = null;
          setState(() { _myBid = null; });
          _loadBids();
          Get.snackbar('Cancelled', 'Your bid has been cancelled!',
              backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        } else {
          final data = jsonDecode(response.body);
          Get.snackbar('Error', data['message'] ?? 'Failed to cancel bid!',
              backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        if (_bookingId == null) return;
        await http.put(Uri.parse('${Constants.baseUrl}/bookings/$_bookingId/cancel'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'});
        await http.delete(Uri.parse('${Constants.baseUrl}/bookings/$_bookingId/delete'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'});
        _isBooking.value = false;
        _isBooked.value  = false;
        _bookingId       = null;
        Get.snackbar('Cancelled', 'Booking cancelled successfully!',
            backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      _isBooking.value = false;
      Get.snackbar('Error', 'Connection error: $e', backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _sendMessage() async {
    final contact = widget.item['contact_preference'] ?? '';
    String phone  = contact.replaceAll(RegExp(r'[^\d]'), '');
    if (!phone.startsWith('975')) phone = '975$phone';
    final itemName = widget.item['item_name'] ?? 'item';
    final price    = widget.item['price'] ?? '';
    final message  = Uri.encodeComponent(
        'Hi! I am interested in your "$itemName" listed for Nu. $price on JNEC Eco-trade. Is it still available?');
    final whatsappUrl = 'https://wa.me/$phone?text=$message';
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('Error', contact.isEmpty ? 'No contact number available!' : 'Could not open WhatsApp!',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _formatCategory(String cat) =>
      cat[0].toUpperCase() + cat.substring(1).replaceAll('_', ' ');

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) { return dateStr; }
  }

  String _timeLeft() {
    if (_auctionEndsAt == null) return '';
    try {
      final endsAt = DateTime.parse(_auctionEndsAt!).toLocal();
      final now    = DateTime.now();
      if (now.isAfter(endsAt)) return 'Auction ended';
      final diff = endsAt.difference(now);
      if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h left';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
      return '${diff.inMinutes}m left';
    } catch (_) { return ''; }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
        ],
      ),
    );
  }

  Widget _whatsAppButton({double height = 48, double fontSize = 14}) {
    return SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: _sendMessage,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 18),
        label: Text('Send Message',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize)),
      ),
    );
  }

  // ✅ Swipeable image section with dot indicators
  Widget _buildImageSection() {
    final images = _images;

    if (images.isEmpty) {
      return Container(
        width: double.infinity, height: 280,
        color: Colors.grey.shade50,
        child: Icon(Icons.image_outlined, size: 80, color: Colors.grey.shade300),
      );
    }

    if (images.length == 1) {
      return Container(
        width: double.infinity, height: 280,
        color: Colors.grey.shade50,
        child: Image.memory(images.first, fit: BoxFit.contain),
      );
    }

    // ✅ Multiple images — swipeable PageView with dots + counter
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) => Container(
              color: Colors.grey.shade50,
              child: Image.memory(images[index], fit: BoxFit.contain),
            ),
          ),

          // ✅ Dot indicators at bottom
          Positioned(
            bottom: 10, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: index == _currentImageIndex ? 14 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _currentImageIndex
                      ? Colors.teal.shade600
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),

          // ✅ Image counter top right
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentImageIndex + 1} / ${images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // ✅ Swipe hint on first view
          if (_currentImageIndex == 0 && images.length > 1)
            Positioned(
              bottom: 30, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Swipe', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('Item Details', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          Obx(() {
            final currentUserEmail = _authController.userEmail.value;
            final sellerEmail      = widget.item['user'] != null ? widget.item['user']['email'] ?? '' : '';
            final isOwner          = currentUserEmail == sellerEmail;
            if (isOwner) return const SizedBox.shrink();
            final saved = _savedController.isSaved(widget.item);
            return IconButton(
              icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? Colors.red : Colors.white),
              onPressed: () => _savedController.toggleSave(widget.item),
            );
          }),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ✅ Swipeable image section
                  _buildImageSection(),

                  // ✅ Auction Banner
                  if (_isAuction)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.teal.shade600,
                      child: Row(
                        children: [
                          const Icon(Icons.gavel, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Auction Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  _highestBid != null
                                      ? 'Highest bid: Nu. ${_highestBid['bid_price']}  •  ${_timeLeft()}'
                                      : 'No bids yet  •  ${_timeLeft()}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Get.to(() => AuctionScreen(item: widget.item));
                              _loadBids();
                            },
                            child: const Text('View Bids', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Item Info Card ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('Item', item['item_name'] ?? ''),
                          _infoRow('Price(Nu)', '${item['price']}'),
                          if (_isAuction && _minBidPrice != null)
                            _infoRow('Min Bid', 'Nu. ${_minBidPrice!.toStringAsFixed(0)}'),
                          _infoRow('Posted on', _formatDate(item['created_at'])),
                          _infoRow('Seller', item['user'] != null ? item['user']['name'] : 'Unknown'),
                          _infoRow('Contact', item['contact_preference'] ?? 'N/A'),
                          _infoRow('Condition', item['condition'] != null
                              ? item['condition'][0].toUpperCase() + item['condition'].substring(1).replaceAll('_', ' ')
                              : ''),
                          _infoRow('Category', item['category'] != null ? _formatCategory(item['category']) : ''),
                          if (item['location'] != null && item['location'].toString().isNotEmpty)
                            _infoRow('Location', item['location']),
                        ],
                      ),
                    ),
                  ),

                  // ✅ Bid Section
                  if (_isAuction)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_myBid != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 10),
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
                                        const Text('Your Current Bid', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                        Text('Nu. ${_myBid['bid_price']}',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _myBid['status'] == 'won' ? Colors.green
                                          : _myBid['status'] == 'lost' ? Colors.red : Colors.orange,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _myBid['status'] == 'won' ? 'Won' : _myBid['status'] == 'lost' ? 'Lost' : 'Active',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_bids.isNotEmpty) ...[
                            Row(
                              children: [
                                Text('Top Bids', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () async {
                                    await Get.to(() => AuctionScreen(item: widget.item));
                                    _loadBids();
                                  },
                                  child: Text('See all ${_bids.length} bids →',
                                      style: TextStyle(color: Colors.teal.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ..._bids.take(3).toList().asMap().entries.map((entry) {
                              final index  = entry.key;
                              final bid    = entry.value;
                              final isTop  = index == 0;
                              final isMine = bid['is_mine'] == true;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMine ? Colors.teal.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isTop ? Colors.amber.shade300 : Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Text(isTop ? '🏆' : '#${index + 1}', style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(
                                      isMine ? 'You' : bid['user']?['name'] ?? 'Bidder',
                                      style: TextStyle(fontWeight: FontWeight.w500,
                                          color: isMine ? Colors.teal.shade700 : Colors.black87),
                                    )),
                                    Text('Nu. ${bid['bid_price']}',
                                        style: TextStyle(fontWeight: FontWeight.bold,
                                            color: isTop ? Colors.amber.shade700 : Colors.teal.shade600)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bottom Buttons ──
          Obx(() {
            final currentUserEmail = _authController.userEmail.value;
            final sellerEmail      = widget.item['user'] != null ? widget.item['user']['email'] ?? '' : '';
            final isOwner          = currentUserEmail == sellerEmail;

            if (isOwner) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))]),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: const Column(children: [
                    Icon(Icons.store_outlined, color: Colors.grey, size: 24),
                    SizedBox(height: 6),
                    Text('This is your item', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('You cannot book or buy your own item', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ),
              );
            }

            if (_isAuction) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.teal.shade300),
                                borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _bidController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: _minBidPrice != null ? 'Min Nu. ${_minBidPrice!.toStringAsFixed(0)}' : 'Enter bid (Nu)',
                                hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isPlacingBid ? null : _placeBid,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                            icon: _isPlacingBid
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.gavel, color: Colors.white, size: 18),
                            label: Text(_myBid != null ? 'Update Bid' : 'Place Bid',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(() => SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _cartController.addToCart(widget.item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cartController.isInCart(widget.item) ? Colors.grey.shade400 : Colors.teal.shade800,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        icon: Icon(_cartController.isInCart(widget.item) ? Icons.shopping_cart : Icons.shopping_cart_outlined,
                            color: Colors.white, size: 16),
                        label: Text(_cartController.isInCart(widget.item) ? 'In Wishlist' : 'Add to Wishlist',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    )),
                    const SizedBox(height: 8),
                    if (_isBooked.value)
                      SizedBox(
                        width: double.infinity, height: 40,
                        child: OutlinedButton(
                          onPressed: _isBooking.value ? null : _cancelBooking,
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                          child: const Text('Cancel Bid', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ WhatsApp button full width
                  _whatsAppButton(height: 48, fontSize: 15),
                  const SizedBox(height: 8),
                  // ✅ Add to Wishlist button
                  Obx(() => SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _cartController.addToCart(widget.item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cartController.isInCart(widget.item)
                            ? Colors.grey.shade400
                            : Colors.teal.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      icon: Icon(
                        _cartController.isInCart(widget.item) ? Icons.shopping_cart : Icons.shopping_cart_outlined,
                        color: Colors.white, size: 18),
                      label: Text(
                        _cartController.isInCart(widget.item) ? 'Added to Wishlist' : 'Add to Wishlist',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}