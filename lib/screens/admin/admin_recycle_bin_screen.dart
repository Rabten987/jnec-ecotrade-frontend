import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

const kAdminColor = Color(0xFF00897B);

class AdminRecycleBinScreen extends StatefulWidget {
  const AdminRecycleBinScreen({super.key});

  @override
  State<AdminRecycleBinScreen> createState() =>
      _AdminRecycleBinScreenState();
}

class _AdminRecycleBinScreenState
    extends State<AdminRecycleBinScreen> {
  List<dynamic> _items = [];
  bool _isLoading      = false;

  @override
  void initState() {
    super.initState();
    _loadBin();
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadBin() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/recycle-bin'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _items = jsonDecode(response.body);
        });
      }
    } catch (e) {
      Get.snackbar('Error',
          'Failed to load recycle bin: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  // ✅ Restore
  Future<void> _restore(
      String type, int id) async {
    try {
      final token = await _getToken();
      final url = type == 'item'
          ? '${Constants.baseUrl}/recycle-bin/items/$id/restore'
          : '${Constants.baseUrl}/recycle-bin/users/$id/restore';

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        Get.snackbar(
            'Restored',
            '${type == 'item' ? 'Item' : 'User'} restored successfully!',
            backgroundColor: kAdminColor,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
        _loadBin();
      }
    } catch (e) {
      Get.snackbar('Error', 'Error: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ✅ Force delete
  Future<void> _forceDelete(
      String type, int id) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16)),
        title: const Text(
            'Permanently Delete'),
        content: const Text(
            'This cannot be undone! Are you sure?'),
        actions: [
          TextButton(
            onPressed: () =>
                Get.back(result: false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight:
                        FontWeight.w600)),
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
            child: const Text(
                'Delete Forever',
                style: TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = await _getToken();
        final url = type == 'item'
            ? '${Constants.baseUrl}/recycle-bin/items/$id/force'
            : '${Constants.baseUrl}/recycle-bin/users/$id/force';

        final response = await http.delete(
          Uri.parse(url),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          Get.snackbar('Deleted',
              'Permanently deleted!',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition:
                  SnackPosition.BOTTOM);
          _loadBin();
        }
      } catch (e) {
        Get.snackbar('Error', 'Error: $e',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition:
                SnackPosition.BOTTOM);
      }
    }
  }

  // ✅ Empty bin
  Future<void> _emptyBin() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16)),
        title:
            const Text('Empty Recycle Bin'),
        content: const Text(
            'This will permanently delete ALL items in the bin. Cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () =>
                Get.back(result: false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight:
                        FontWeight.w600)),
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
            child: const Text('Empty All',
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
              '${Constants.baseUrl}/recycle-bin/empty'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          Get.snackbar('Emptied',
              'Recycle bin emptied!',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition:
                  SnackPosition.BOTTOM);
          _loadBin();
        }
      } catch (e) {
        Get.snackbar('Error', 'Error: $e',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition:
                SnackPosition.BOTTOM);
      }
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff =
          DateTime.now().difference(date);
      if (diff.inDays > 0)
        return '${diff.inDays}d ago';
      if (diff.inHours > 0)
        return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: kAdminColor,
        foregroundColor: Colors.white,
        title: const Text(
          'Recycle Bin',
          style: TextStyle(
              fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBin,
          ),
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _emptyBin,
              child: const Text(
                'Empty',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: kAdminColor))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                          Icons
                              .delete_outline_outlined,
                          size: 70,
                          color: Colors
                              .grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Recycle bin is empty',
                        style: TextStyle(
                          color:
                              Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleted items appear here for 30 days',
                        style: TextStyle(
                          color:
                              Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [

                    // ✅ Info banner
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10),
                      color: Colors.orange.shade50,
                      child: Row(
                        children: [
                          Icon(
                              Icons.info_outline,
                              color: Colors
                                  .orange.shade700,
                              size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Items are automatically deleted after 30 days',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors
                                    .orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadBin,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.all(
                                  16),
                          itemCount: _items.length,
                          itemBuilder:
                              (context, index) {
                            final item =
                                _items[index];
                            final type =
                                item['type'] ??
                                    'item';
                            final isItem =
                                type == 'item';
                            final daysLeft =
                                item['days_left'] ??
                                    0;

                            Uint8List? imageBytes;
                            if (item['image'] !=
                                    null &&
                                item['image']
                                    .toString()
                                    .isNotEmpty) {
                              try {
                                imageBytes =
                                    base64Decode(
                                        item[
                                            'image']);
                              } catch (_) {}
                            }

                            return Container(
                              margin: const EdgeInsets
                                  .only(bottom: 10),
                              decoration:
                                  BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            12),
                                border: Border.all(
                                    color: Colors
                                        .grey
                                        .shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors
                                        .black
                                        .withOpacity(
                                            0.05),
                                    blurRadius: 4,
                                    offset:
                                        const Offset(
                                            0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets
                                        .all(10),
                                child: Row(
                                  children: [

                                    // ✅ Image/Icon
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  8),
                                      child:
                                          Container(
                                        width: 55,
                                        height: 55,
                                        color: isItem
                                            ? kAdminColor
                                                .withOpacity(
                                                    0.1)
                                            : Colors
                                                .blue
                                                .shade50,
                                        child: imageBytes !=
                                                null
                                            ? Image
                                                .memory(
                                                imageBytes,
                                                fit: BoxFit
                                                    .cover,
                                              )
                                            : Icon(
                                                isItem
                                                    ? Icons
                                                        .inventory_2_outlined
                                                    : Icons
                                                        .person_outline,
                                                color: isItem
                                                    ? kAdminColor
                                                    : Colors
                                                        .blue
                                                        .shade600,
                                                size:
                                                    28,
                                              ),
                                      ),
                                    ),

                                    const SizedBox(
                                        width: 10),

                                    // ✅ Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [

                                          // Type badge
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                    6,
                                                vertical:
                                                    2),
                                            decoration:
                                                BoxDecoration(
                                              color: isItem
                                                  ? kAdminColor
                                                      .withOpacity(
                                                          0.1)
                                                  : Colors
                                                      .blue
                                                      .shade50,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          10),
                                            ),
                                            child: Text(
                                              isItem
                                                  ? '📦 Item'
                                                  : '👤 User',
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    10,
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                                color: isItem
                                                    ? kAdminColor
                                                    : Colors
                                                        .blue
                                                        .shade600,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(
                                              height: 3),

                                          // Name
                                          Text(
                                            item['name'] ??
                                                '',
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                              fontSize:
                                                  13,
                                            ),
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),

                                          // Detail
                                          Text(
                                            item['detail'] ??
                                                '',
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  11,
                                              color: Colors
                                                  .grey
                                                  .shade600,
                                            ),
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),

                                          const SizedBox(
                                              height: 3),

                                          // Days left
                                          Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .timer_outlined,
                                                size:
                                                    11,
                                                color: daysLeft <=
                                                        5
                                                    ? Colors
                                                        .red
                                                    : Colors
                                                        .orange
                                                        .shade600,
                                              ),
                                              const SizedBox(
                                                  width:
                                                      3),
                                              Text(
                                                '$daysLeft days left',
                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      10,
                                                  color: daysLeft <=
                                                          5
                                                      ? Colors
                                                          .red
                                                      : Colors
                                                          .orange
                                                          .shade600,
                                                  fontWeight:
                                                      FontWeight
                                                          .w500,
                                                ),
                                              ),
                                              const SizedBox(
                                                  width:
                                                      6),
                                              Text(
                                                _timeAgo(
                                                    item['deleted_at']),
                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      10,
                                                  color: Colors
                                                      .grey
                                                      .shade400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ✅ Actions
                                    Column(
                                      mainAxisSize:
                                          MainAxisSize
                                              .min,
                                      children: [

                                        // ✅ Restore
                                        InkWell(
                                          onTap: () =>
                                              _restore(
                                            type,
                                            item['id'],
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      8),
                                          child:
                                              Padding(
                                            padding: const EdgeInsets
                                                .all(6),
                                            child:
                                                Column(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .restore,
                                                    color:
                                                        kAdminColor,
                                                    size:
                                                        20),
                                                Text(
                                                    'Restore',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: kAdminColor,
                                                        fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                            height: 4),

                                        // ✅ Delete Forever
                                        InkWell(
                                          onTap: () =>
                                              _forceDelete(
                                            type,
                                            item['id'],
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      8),
                                          child:
                                              Padding(
                                            padding: const EdgeInsets
                                                .all(6),
                                            child:
                                                Column(
                                              children: [
                                                const Icon(
                                                    Icons
                                                        .delete_forever,
                                                    color:
                                                        Colors.red,
                                                    size:
                                                        20),
                                                const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: Colors.red,
                                                        fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}