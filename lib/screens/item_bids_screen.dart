import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// ✅ Second-level screen — shows all bids placed on ONE specific item.
/// Reached by tapping an item card on OffersReceivedScreen.
class ItemBidsScreen extends StatefulWidget {
  final dynamic item;
  final List<dynamic> bids;

  const ItemBidsScreen({super.key, required this.item, required this.bids});

  @override
  State<ItemBidsScreen> createState() => _ItemBidsScreenState();
}

class _ItemBidsScreenState extends State<ItemBidsScreen> {
  late List<dynamic> _bids;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _bids = List<dynamic>.from(widget.bids);
    // ✅ Sort: highest bid first
    _bids.sort((a, b) {
      final aPrice = double.tryParse(a['bid_price']?.toString() ?? '0') ?? 0.0;
      final bPrice = double.tryParse(b['bid_price']?.toString() ?? '0') ?? 0.0;
      return bPrice.compareTo(aPrice);
    });
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _refreshBids() async {
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
        final itemId = widget.item['id'];
        final filtered = data.where((b) {
          final i = b['item'] ?? {};
          return i['id'] == itemId;
        }).toList();
        filtered.sort((a, b) {
          final aPrice = double.tryParse(a['bid_price']?.toString() ?? '0') ?? 0.0;
          final bPrice = double.tryParse(b['bid_price']?.toString() ?? '0') ?? 0.0;
          return bPrice.compareTo(aPrice);
        });
        setState(() => _bids = filtered);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to refresh: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _acceptBooking(int id) async {
    final confirm = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Accept Bid'),
      content: const Text(
          'Accept this bid? All other bids for this item will be rejected automatically.'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Accept', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    if (confirm == true) await _updateBooking(id, 'accept');
  }

  Future<void> _rejectBooking(int id) async {
    final confirm = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reject Bid'),
      content: const Text('Are you sure you want to reject this bid?'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Reject', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    if (confirm == true) await _updateBooking(id, 'reject');
  }

  Future<void> _updateBooking(int id, String action) async {
    try {
      final token    = await _getToken();
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
          action == 'accept' ? 'Bid Accepted!' : 'Bid Rejected!',
          action == 'accept'
              ? 'Bid accepted. All other bids rejected automatically.'
              : 'The bid has been rejected.',
          backgroundColor: action == 'accept' ? Colors.teal.shade600 : Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        _refreshBids();
      } else {
        final data = jsonDecode(response.body);
        Get.snackbar('Error', data['message'] ?? 'Failed!',
            backgroundColor: Colors.red, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
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
          '${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) { return dateStr; }
  }

  bool _auctionEnded() {
    if (widget.item['auction_ends_at'] == null) return false;
    try {
      return DateTime.now().toUtc()
          .isAfter(DateTime.parse(widget.item['auction_ends_at']).toUtc());
    } catch (_) { return false; }
  }

  String _timeLeft() {
    if (widget.item['auction_ends_at'] == null) return '';
    try {
      final endsAt = DateTime.parse(widget.item['auction_ends_at']).toLocal();
      final now    = DateTime.now();
      if (now.isAfter(endsAt)) return 'Auction Ended';
      final diff = endsAt.difference(now);
      if (diff.inDays > 0)  return '${diff.inDays}d left';
      if (diff.inHours > 0) return '${diff.inHours}h left';
      return '${diff.inMinutes}m left';
    } catch (_) { return ''; }
  }

  Future<void> _contactWinner(dynamic buyer, double bidPrice) async {
    final phone = (buyer['phone'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
    final fullPhone = phone.startsWith('975') ? phone : '975$phone';
    final itemName  = widget.item['item_name'] ?? 'item';
    final message   = Uri.encodeComponent(
      '🎉 Congratulations! You won the auction for "$itemName" '
      'with a bid of Nu. ${bidPrice.toStringAsFixed(2)} on JNEC Eco-Trade (ReDruk). '
      'Please contact me to arrange the exchange.',
    );
    final url = 'https://wa.me/$fullPhone?text=$message';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'Cannot Open WhatsApp',
        phone.isEmpty
            ? 'Winner has no phone number on their profile.'
            : 'Could not open WhatsApp.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ended    = _auctionEnded();
    final timeLeft = _timeLeft();

    double highestBid = 0;
    for (final b in _bids) {
      final p = double.tryParse(b['bid_price']?.toString() ?? '0') ?? 0.0;
      if (p > highestBid) highestBid = p;
    }

    final Uint8List? imageBytes = ImageHelper.getFirstImage(item['image']);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: Text(item['item_name'] ?? 'Bids',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshBids),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: _refreshBids,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ── Item summary card ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['item_name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                highestBid > 0
                                    ? 'Highest bid: Nu. ${highestBid.toStringAsFixed(2)}'
                                    : 'Nu. ${item['price'] ?? ''}',
                                style: TextStyle(
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              if (timeLeft.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(timeLeft,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: ended
                                            ? Colors.red
                                            : Colors.orange.shade700,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text('${_bids.length} bid${_bids.length == 1 ? '' : 's'} on this item',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700, fontSize: 13)),

                  const SizedBox(height: 10),

                  // ── Bid list ──
                  ..._bids.map((booking) {
                    final buyer     = booking['user'] ?? {};
                    final status    = booking['status'] ?? 'pending';
                    final bidPrice  = double.tryParse(
                            booking['bid_price']?.toString() ?? '0') ?? 0.0;
                    final isHighest = bidPrice > 0 && bidPrice == highestBid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isHighest
                              ? Colors.amber.shade400
                              : Colors.grey.shade200,
                          width: isHighest ? 2 : 1,
                        ),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Badge row ──
                            Row(
                              children: [
                                if (isHighest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: Colors.amber.shade600,
                                        borderRadius: BorderRadius.circular(6)),
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
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(_statusLabel(status),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // ── Buyer + bid ──
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.teal.shade50,
                                  child: Icon(Icons.person,
                                      color: Colors.teal.shade600, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(buyer['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Bid: Nu. ${bidPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            color: Colors.teal.shade700,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text('Bid on: ${_formatDate(booking['created_at'])}',
                                    style: TextStyle(
                                        color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),

                            // ── Info banner — only for highest bid ──
                            if (status == 'pending' && !ended && isHighest) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 15, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'This is the highest bidder. You can accept now or wait for auction to end.',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.blue.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── Accept / Reject — only for highest bid ──
                            if (status == 'pending' && isHighest) ...[
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
                                          backgroundColor: Colors.amber.shade600,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text(
                                          'Accept Winner',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
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
                                          side: const BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Reject',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (status == 'pending' && !isHighest) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline,
                                        size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Only the highest bidder can be accepted.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── Winner — contact button ──
                            if (status == 'confirmed') ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _contactWinner(buyer, bidPrice),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30)),
                                  ),
                                  icon: const FaIcon(FontAwesomeIcons.whatsapp,
                                      color: Colors.white, size: 18),
                                  label: const Text(
                                    'Contact Winner on WhatsApp',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}