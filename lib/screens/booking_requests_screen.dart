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
      // ✅ GetX snackbar
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
    // ✅ GetX dialog
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Booking'),
        content: const Text(
            'Are you sure you want to accept this booking request?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel',
                style:
                    TextStyle(color: Colors.grey.shade600)),
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
    // ✅ GetX dialog
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
                style:
                    TextStyle(color: Colors.grey.shade600)),
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
        Uri.parse(
            '${Constants.baseUrl}/bookings/$id/$action'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // ✅ GetX snackbar
        Get.snackbar(
          action == 'accept'
              ? 'Booking Accepted!'
              : 'Booking Rejected!',
          action == 'accept'
              ? 'The booking has been accepted successfully.'
              : 'The booking has been rejected.',
          backgroundColor: action == 'accept'
              ? Colors.teal.shade600
              : Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        _loadRequests();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update booking: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade600;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Accepted';
      case 'cancelled':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'Booking Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // ✅ GetX back
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
              child: CircularProgressIndicator(
                  color: Colors.teal))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 60,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No booking requests yet',
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16),
                      ),
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
                      final item   = booking['item'] ?? {};
                      final buyer  = booking['user'] ?? {};
                      final status =
                          booking['status'] ?? 'pending';

                      Uint8List? imageBytes;
                      if (item['image'] != null &&
                          item['image']
                              .toString()
                              .isNotEmpty) {
                        try {
                          imageBytes =
                              base64Decode(item['image']);
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(
                            bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [

                              // ── Item Info ──
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
                                    child: SizedBox(
                                      width: 70,
                                      height: 70,
                                      child: imageBytes !=
                                              null
                                          ? Image.memory(
                                              imageBytes,
                                              fit: BoxFit
                                                  .cover)
                                          : Container(
                                              color: Colors
                                                  .grey
                                                  .shade100,
                                              child: Icon(
                                                Icons
                                                    .image_outlined,
                                                color: Colors
                                                    .grey
                                                    .shade300,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          item['item_name'] ??
                                              '',
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 4),
                                        Text(
                                          'Nu. ${item['price'] ?? ''}',
                                          style: TextStyle(
                                            color: Colors
                                                .teal.shade600,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 4),
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 2),
                                          decoration:
                                              BoxDecoration(
                                            color: _statusColor(
                                                    status)
                                                .withOpacity(
                                                    0.1),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        20),
                                          ),
                                          child: Text(
                                            _statusLabel(
                                                status),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _statusColor(
                                                  status),
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              Divider(
                                  color:
                                      Colors.grey.shade200),
                              const SizedBox(height: 8),

                              // ── Buyer Info ──
                              Row(
                                children: [
                                  Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: Colors
                                          .grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Requested by: ',
                                    style: TextStyle(
                                      color: Colors
                                          .grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    buyer['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              Row(
                                children: [
                                  Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors
                                          .grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Date: ${_formatDate(booking['created_at'])}',
                                    style: TextStyle(
                                      color: Colors
                                          .grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              // ── Accept/Reject Buttons ──
                              if (status == 'pending') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child:
                                            ElevatedButton(
                                          onPressed: () =>
                                              _acceptBooking(
                                                  booking[
                                                      'id']),
                                          style: ElevatedButton
                                              .styleFrom(
                                            backgroundColor:
                                                Colors.teal
                                                    .shade600,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            8)),
                                          ),
                                          child: const Text(
                                            'Accept',
                                            style: TextStyle(
                                                color: Colors
                                                    .white,
                                                fontWeight:
                                                    FontWeight
                                                        .bold),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child:
                                            OutlinedButton(
                                          onPressed: () =>
                                              _rejectBooking(
                                                  booking[
                                                      'id']),
                                          style: OutlinedButton
                                              .styleFrom(
                                            side: const BorderSide(
                                                color: Colors
                                                    .red),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            8)),
                                          ),
                                          child: const Text(
                                            'Reject',
                                            style: TextStyle(
                                                color: Colors
                                                    .red,
                                                fontWeight:
                                                    FontWeight
                                                        .bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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