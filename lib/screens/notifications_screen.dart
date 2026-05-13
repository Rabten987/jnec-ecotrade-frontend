import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
  final _homeController =
      Get.find<HomeController>();

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
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/notifications'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _notifications =
              jsonDecode(response.body);
        });
        _homeController.loadUnreadCount();
      }
    } catch (e) {
      Get.snackbar('Error',
          'Failed to load notifications: $e',
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
        Uri.parse(
            '${Constants.baseUrl}/notifications/read-all'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      _homeController.unreadCount.value = 0;
      setState(() {
        _notifications = _notifications.map((n) {
          return {...n, 'is_read': true};
        }).toList();
      });
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  // ✅ Clear all notifications
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
            onPressed: () =>
                Get.back(result: false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () =>
                Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
            child: const Text('Clear',
                style: TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = await _getToken();
        final response = await http.delete(
          Uri.parse(
              '${Constants.baseUrl}/notifications/clear'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            _notifications = [];
          });
          _homeController.unreadCount.value = 0;
          Get.snackbar(
              'Cleared',
              'All notifications cleared!',
              backgroundColor:
                  Colors.teal.shade600,
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

  IconData _getIcon(String type) {
    switch (type) {
      case 'posted':
        return Icons.upload_outlined;
      case 'booked':
        return Icons.bookmark_outlined;
      case 'approved':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'new_item':
        return Icons.new_releases_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'posted':
        return Colors.teal.shade600;
      case 'booked':
        return Colors.blue.shade600;
      case 'approved':
        return Colors.green.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      case 'new_item':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff =
          DateTime.now().difference(date);
      if (diff.inSeconds < 60)
        return '${diff.inSeconds}s';
      if (diff.inMinutes < 60)
        return '${diff.inMinutes}m';
      if (diff.inHours < 24)
        return '${diff.inHours}h';
      if (diff.inDays < 7)
        return '${diff.inDays}d';
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
        title: const Text(
          'Notifications',
          style: TextStyle(
              fontWeight: FontWeight.bold),
        ),
        actions: [
          // ✅ Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndMarkAll,
          ),
          // ✅ Clear button
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.teal))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons
                            .notifications_off_outlined,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                            color:
                                Colors.grey.shade400,
                            fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAndMarkAll,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.all(12),
                    itemCount:
                        _notifications.length,
                    itemBuilder: (context, index) {
                      final notif =
                          _notifications[index];
                      final isRead =
                          notif['is_read'] == true ||
                              notif['is_read'] == 1;
                      final type =
                          notif['type'] ?? 'general';

                      return Container(
                        margin:
                            const EdgeInsets.only(
                                bottom: 8),
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.white
                              : Colors.teal.shade50,
                          borderRadius:
                              BorderRadius.circular(
                                  12),
                          border: Border.all(
                            color: isRead
                                ? Colors.grey.shade200
                                : Colors
                                    .teal.shade100,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.04),
                              blurRadius: 4,
                              offset:
                                  const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            // ── Icon ──
                            Container(
                              width: 42,
                              height: 42,
                              decoration:
                                  BoxDecoration(
                                color: _getColor(type)
                                    .withOpacity(0.1),
                                shape:
                                    BoxShape.circle,
                              ),
                              child: Icon(
                                _getIcon(type),
                                color:
                                    _getColor(type),
                                size: 22,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // ── Message ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    notif['title'] ??
                                        '',
                                    style:
                                        const TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      color: Colors
                                          .black87,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 2),
                                  Text(
                                    notif['message'] ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors
                                          .grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 4),
                                  Text(
                                    _timeAgo(notif[
                                        'created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors
                                          .grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Unread dot ──
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .teal.shade600,
                                  shape:
                                      BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}