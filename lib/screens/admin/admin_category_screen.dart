import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

const kAdminColor = Color(0xFF00897B);

class AdminCategoryScreen extends StatefulWidget {
  final List<dynamic> items;
  final List<Map<String, dynamic>> categories;

  const AdminCategoryScreen({
    super.key,
    required this.items,
    required this.categories,
  });

  @override
  State<AdminCategoryScreen> createState() =>
      _AdminCategoryScreenState();
}

class _AdminCategoryScreenState
    extends State<AdminCategoryScreen> {
  List<dynamic> _categories = [];
  bool _isLoading           = false;

  // ✅ Draggable FAB position
  double _fabX          = 0;
  double _fabY          = 0;
  bool _fabPositioned   = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/admin/categories/stats'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _categories = jsonDecode(response.body);
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  // ✅ Add category dialog
  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final confirm    = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Category Name',
            labelStyle: const TextStyle(
                color: Colors.black54),
            hintText: 'e.g. Sports',
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: Colors.grey.shade300)),
            focusedBorder:
                const UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: kAdminColor)),
          ),
          autofocus: true,
          textCapitalization:
              TextCapitalization.words,
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
            child: const Text('Add',
                style: TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true &&
        controller.text.isNotEmpty) {
      try {
        final token    = await _getToken();
        final response = await http.post(
          Uri.parse(
              '${Constants.baseUrl}/admin/categories'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': controller.text.trim(),
          }),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 201) {
          Get.snackbar('Added', 'Category added!',
              backgroundColor: kAdminColor,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
          _loadCategories();
        } else {
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
    controller.dispose();
  }

  // ✅ Delete category
  Future<void> _deleteCategory(
      int id, String name, int count) async {
    if (count > 0) {
      Get.snackbar(
        'Cannot Delete',
        '$name has $count items. Remove items first!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category'),
        content: Text('Delete "$name" category?'),
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
              '${Constants.baseUrl}/admin/categories/$id'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          Get.snackbar('Deleted',
              'Category deleted!',
              backgroundColor: kAdminColor,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
          _loadCategories();
        } else {
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
  }

  IconData _getCategoryIcon(String value) {
    switch (value) {
      case 'stationary':
        return Icons.edit_outlined;
      case 'clothing':
        return Icons.checkroom_outlined;
      case 'furniture':
        return Icons.chair_outlined;
      case 'kitchen_utensils':
        return Icons.kitchen_outlined;
      case 'electronic':
        return Icons.devices_outlined;
      case 'miscellaneous':
        return Icons.category_outlined;
      case 'others':
        return Icons.more_horiz_outlined;
      default:
        return Icons.label_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Set initial FAB position
    if (!_fabPositioned) {
      _fabX = MediaQuery.of(context).size.width - 80;
      _fabY =
          MediaQuery.of(context).size.height - 180;
      _fabPositioned = true;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: kAdminColor,
        foregroundColor: Colors.white,
        title: const Text('Item Category',
            style: TextStyle(
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
          ),
        ],
      ),
      body: Stack(
        children: [

          // ── Main Content ──
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: kAdminColor))
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: _categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Icon(
                                  Icons
                                      .category_outlined,
                                  size: 60,
                                  color: Colors
                                      .grey.shade300),
                              const SizedBox(
                                  height: 12),
                              Text(
                                  'No categories yet',
                                  style: TextStyle(
                                      color: Colors
                                          .grey.shade400,
                                      fontSize: 16)),
                              const SizedBox(
                                  height: 16),
                              ElevatedButton.icon(
                                onPressed:
                                    _addCategory,
                                icon: const Icon(
                                    Icons.add),
                                label: const Text(
                                    'Add Category'),
                                style: ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                      kAdminColor,
                                  foregroundColor:
                                      Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(
                                  16, 16, 16, 80),
                          itemCount:
                              _categories.length,
                          itemBuilder:
                              (context, index) {
                            final cat =
                                _categories[index];
                            final count =
                                cat['count'] ?? 0;
                            final name =
                                cat['name'] ?? '';
                            final value =
                                cat['value'] ?? '';
                            final id = cat['id'];

                            return Container(
                              margin:
                                  const EdgeInsets
                                      .only(bottom: 10),
                              padding:
                                  const EdgeInsets.all(
                                      16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius
                                        .circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(
                                            0.05),
                                    blurRadius: 4,
                                    offset: const Offset(
                                        0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [

                                  // ── Icon ──
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .all(10),
                                    decoration:
                                        BoxDecoration(
                                      color: const Color(
                                          0xFFE0F2F1),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  10),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(
                                          value),
                                      color: kAdminColor,
                                      size: 24,
                                    ),
                                  ),

                                  const SizedBox(
                                      width: 16),

                                  // ── Name + Count ──
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          name,
                                          style:
                                              const TextStyle(
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight
                                                    .w600,
                                            color: Colors
                                                .black87,
                                          ),
                                        ),
                                        Text(
                                          '$count items',
                                          style:
                                              TextStyle(
                                            fontSize: 12,
                                            color: Colors
                                                .grey
                                                .shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ── Count Badge ──
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                            horizontal:
                                                12,
                                            vertical: 6),
                                    decoration:
                                        BoxDecoration(
                                      color: kAdminColor,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  20),
                                    ),
                                    child: Text(
                                      '$count',
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                      width: 8),

                                  // ── Delete Button ──
                                  IconButton(
                                    icon: Icon(
                                      Icons
                                          .delete_outline,
                                      color: count > 0
                                          ? Colors.grey
                                              .shade400
                                          : Colors.red,
                                      size: 22,
                                    ),
                                    onPressed: () =>
                                        _deleteCategory(
                                            id,
                                            name,
                                            count),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

          // ✅ Draggable FAB
          Positioned(
            left: _fabX,
            top:  _fabY,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _fabX += details.delta.dx;
                  _fabY += details.delta.dy;

                  // ✅ Keep within screen bounds
                  final size =
                      MediaQuery.of(context).size;
                  _fabX = _fabX.clamp(
                      0, size.width - 60);
                  _fabY = _fabY.clamp(
                      0, size.height - 120);
                });
              },
              onTap: _addCategory,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kAdminColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}