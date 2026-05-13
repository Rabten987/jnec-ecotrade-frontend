import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

const kAdminColor = Color(0xFF00897B);

class AdminItemManageScreen extends StatefulWidget {
  final List<dynamic> items;
  final VoidCallback onRefresh;

  const AdminItemManageScreen({
    super.key,
    required this.items,
    required this.onRefresh,
  });

  @override
  State<AdminItemManageScreen> createState() =>
      _AdminItemManageScreenState();
}

class _AdminItemManageScreenState
    extends State<AdminItemManageScreen> {
  late List<dynamic> _allItems;
  List<dynamic> _filteredItems = [];
  String _searchText           = '';
  String _selectedFilter       = 'All';

  final List<String> _filters = [
    'All', 'Available', 'Booked', 'Sold'
  ];

  @override
  void initState() {
    super.initState();
    _allItems      = List.from(widget.items);
    _filteredItems = List.from(widget.items);
  }

  void _applyFilter() {
    setState(() {
      _filteredItems = _allItems.where((item) {
        final name   =
            (item['item_name'] ?? '')
                .toString()
                .toLowerCase();
        final status =
            (item['status'] ?? 'available')
                .toString()
                .toLowerCase();

        final matchSearch =
            _searchText.isEmpty ||
            name.contains(
                _searchText.toLowerCase());

        final matchFilter =
            _selectedFilter == 'All' ||
            (_selectedFilter == 'Available' &&
                status == 'available') ||
            (_selectedFilter == 'Booked' &&
                status == 'booked') ||
            (_selectedFilter == 'Sold' &&
                status == 'sold');

        return matchSearch && matchFilter;
      }).toList();
    });
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // ✅ Delete item
  Future<void> _deleteItem(
      int itemId, String itemName) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item'),
        content: Text('Delete "$itemName"?'),
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
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token    = await _getToken();
        final response = await http.delete(
          Uri.parse(
              '${Constants.baseUrl}/admin/items/$itemId'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            _allItems.removeWhere(
                (item) => item['id'] == itemId);
            _applyFilter();
          });
          widget.onRefresh();
          Get.snackbar('Deleted', 'Item deleted!',
              backgroundColor: kAdminColor,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        } else {
          Get.snackbar('Error', 'Failed to delete!',
              backgroundColor: Colors.red,
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

  // ✅ Edit item details
  Future<void> _editItem(dynamic item) async {
    final nameController = TextEditingController(
        text: item['item_name']);
    final priceController = TextEditingController(
        text: item['price'].toString());
    final locationController = TextEditingController(
        text: item['location'] ?? '');

    String selectedCondition =
        item['condition'] ?? 'used';
    String selectedCategory =
        item['category'] ?? 'others';

    final conditions = ['new', 'used', 'like_new'];
    final categories = [
      'stationary', 'clothing', 'furniture',
      'kitchen_utensils', 'electronic',
      'miscellaneous', 'others'
    ];

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Item Name ──
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      labelStyle: TextStyle(
                          color: Colors.black54),
                      focusedBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Price ──
                  TextField(
                    controller: priceController,
                    keyboardType:
                        TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (Nu.)',
                      labelStyle: TextStyle(
                          color: Colors.black54),
                      focusedBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Condition ──
                  DropdownButtonFormField<String>(
                    value: selectedCondition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      labelStyle: TextStyle(
                          color: Colors.black54),
                    ),
                    items: conditions.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c[0].toUpperCase() +
                              c.substring(1)
                                  .replaceAll(
                                      '_', ' '),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setStateDialog(() =>
                            selectedCondition = val!),
                  ),
                  const SizedBox(height: 12),

                  // ── Category ──
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(
                          color: Colors.black54),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c[0].toUpperCase() +
                              c.substring(1)
                                  .replaceAll(
                                      '_', ' '),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setStateDialog(() =>
                            selectedCategory = val!),
                  ),
                  const SizedBox(height: 12),

                  // ── Location ──
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      labelStyle: TextStyle(
                          color: Colors.black54),
                      focusedBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
              backgroundColor: kAdminColor,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token    = await _getToken();
        final response = await http.put(
          Uri.parse(
              '${Constants.baseUrl}/admin/items/${item['id']}'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'item_name': nameController.text,
            'price': double.tryParse(
                    priceController.text) ??
                0,
            'condition': selectedCondition,
            'category':  selectedCategory,
            'location':  locationController.text,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            final idx = _allItems.indexWhere(
                (i) => i['id'] == item['id']);
            if (idx != -1) {
              _allItems[idx] = data['item'];
            }
            _applyFilter();
          });
          widget.onRefresh();
          Get.snackbar('Updated', 'Item updated!',
              backgroundColor: kAdminColor,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        } else {
          final data = jsonDecode(response.body);
          Get.snackbar('Error',
              data['message'] ?? 'Failed!',
              backgroundColor: Colors.red,
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

    nameController.dispose();
    priceController.dispose();
    locationController.dispose();
  }

  // ✅ Status colors
  Color _statusColor(String status) {
    switch (status) {
      case 'available': return Colors.green.shade600;
      case 'booked':    return Colors.orange.shade600;
      case 'sold':      return Colors.red.shade600;
      default:          return Colors.grey.shade600;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green.withOpacity(0.1);
      case 'booked':
        return Colors.orange.withOpacity(0.1);
      case 'sold':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'available': return 'Available';
      case 'booked':    return 'Booked (Negotiating)';
      case 'sold':      return 'Sold';
      default:          return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: kAdminColor,
        foregroundColor: Colors.white,
        title: const Text('Manage Item',
            style: TextStyle(
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [

          // ── Search Bar ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
                16, 12, 16, 8),
            child: TextField(
              onChanged: (val) {
                _searchText = val;
                _applyFilter();
              },
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13),
                prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(
                        vertical: 0),
              ),
            ),
          ),

          // ── Filter Chips ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected =
                      _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      _applyFilter();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(
                          right: 8),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kAdminColor
                            : Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? kAdminColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : Colors.black54,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Item Count ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filteredItems.length} items',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── Items List ──
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                            Icons.inventory_2_outlined,
                            size: 60,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No items found',
                            style: TextStyle(
                                color:
                                    Colors.grey.shade400,
                                fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item =
                          _filteredItems[index];
                      final status =
                          item['status'] ??
                              'available';

                      Uint8List? imageBytes;
                      if (item['image'] != null &&
                          item['image']
                              .toString()
                              .isNotEmpty) {
                        try {
                          imageBytes = base64Decode(
                              item['image']);
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(
                            bottom: 12),
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                                  12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.05),
                              blurRadius: 4,
                              offset:
                                  const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [

                            // ── Image ──
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                      8),
                              child: SizedBox(
                                width: 65,
                                height: 65,
                                child: imageBytes != null
                                    ? Image.memory(
                                        imageBytes,
                                        fit: BoxFit.cover)
                                    : Container(
                                        color: Colors
                                            .grey.shade100,
                                        child: Icon(
                                          Icons
                                              .image_outlined,
                                          color: Colors
                                              .grey.shade300,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // ── Info ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    item['item_name'] ??
                                        '',
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis,
                                  ),
                                  const SizedBox(
                                      height: 3),
                                  Text(
                                    'Nu. ${item['price']}',
                                    style:
                                        const TextStyle(
                                      color: kAdminColor,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 4),

                                  // ── Status Badge ──
                                  Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        horizontal: 8,
                                        vertical: 3),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          _statusBgColor(
                                              status),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  20),
                                      border: Border.all(
                                        color: _statusColor(
                                                status)
                                            .withOpacity(
                                                0.3),
                                      ),
                                    ),
                                    child: Text(
                                      _statusLabel(
                                          status),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            _statusColor(
                                                status),
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 3),
                                  Text(
                                    item['user'] != null
                                        ? 'By: ${item['user']['name']}'
                                        : '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors
                                          .grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Edit + Delete ──
                            Column(
                              children: [
                                // ✅ Edit button
                                IconButton(
                                  icon: const Icon(
                                      Icons.edit_outlined,
                                      color: kAdminColor,
                                      size: 22),
                                  onPressed: () =>
                                      _editItem(item),
                                ),
                                // ✅ Delete button
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 22),
                                  onPressed: () =>
                                      _deleteItem(
                                          item['id'],
                                          item['item_name']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}