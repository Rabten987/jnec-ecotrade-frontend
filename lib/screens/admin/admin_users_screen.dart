import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

const kAdminColor = Color(0xFF00897B);

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() =>
      _AdminUsersScreenState();
}

class _AdminUsersScreenState
    extends State<AdminUsersScreen> {
  List<dynamic> _allUsers      = [];
  List<dynamic> _filteredUsers = [];
  String _searchText           = '';
  int _total                   = 0;
  bool _isLoading              = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/admin/users'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _total       = data['total'] ?? 0;
          _allUsers    = data['users']  ?? [];
          _filteredUsers =
              List.from(_allUsers);
        });
      }
    } catch (e) {
      Get.snackbar('Error',
          'Failed to load users: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  void _applySearch(String text) {
    setState(() {
      _searchText = text;
      if (text.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((u) {
          final name  = (u['name']  ?? '')
              .toString().toLowerCase();
          final email = (u['email'] ?? '')
              .toString().toLowerCase();
          final phone = (u['phone'] ?? '')
              .toString().toLowerCase();
          return name.contains(
                  text.toLowerCase()) ||
              email.contains(
                  text.toLowerCase()) ||
              phone.contains(
                  text.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteUser(
      int userId, String userName) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16)),
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to remove "$userName"?'),
        actions: [
          TextButton(
            onPressed: () =>
                Get.back(result: false),
            child: Text('Cancel',
                style: TextStyle(
                    color:
                        Colors.grey.shade600)),
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
            child: const Text('Remove',
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
              '${Constants.baseUrl}/admin/users/$userId'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            _allUsers.removeWhere(
                (u) => u['id'] == userId);
            _filteredUsers.removeWhere(
                (u) => u['id'] == userId);
            _total = _allUsers.length;
          });
          Get.snackbar('Removed',
              'User removed successfully!',
              backgroundColor: kAdminColor,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        } else {
          final data =
              jsonDecode(response.body);
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

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff =
          DateTime.now().difference(date);
      if (diff.inDays >= 30)
        return '${(diff.inDays / 30).floor()} month(s) ago';
      if (diff.inDays >= 1)
        return '${diff.inDays} day(s) ago';
      if (diff.inHours >= 1)
        return '${diff.inHours} hour(s) ago';
      return 'Just now';
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
        title: const Text('Manage Users',
            style: TextStyle(
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: kAdminColor))
          : Column(
              children: [

                // ── Total Users Banner ──
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding:
                      const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(
                                12),
                        decoration: BoxDecoration(
                          color: kAdminColor
                              .withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(
                                  12),
                        ),
                        child: const Icon(
                          Icons.people_outline,
                          color: kAdminColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            '$_total',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.bold,
                              color: kAdminColor,
                            ),
                          ),
                          Text(
                            'Total Users',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors
                                  .grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Search Bar ──
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.fromLTRB(
                          16, 8, 16, 12),
                  child: TextField(
                    onChanged: _applySearch,
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, email or phone...',
                      hintStyle: TextStyle(
                          color:
                              Colors.grey.shade400,
                          fontSize: 13),
                      prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey),
                      filled: true,
                      fillColor:
                          Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                                10),
                        borderSide:
                            BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              vertical: 0),
                    ),
                  ),
                ),

                // ── Results Count ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredUsers.length} users',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Users List ──
                Expanded(
                  child: _filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Icon(
                                  Icons
                                      .people_outline,
                                  size: 60,
                                  color: Colors
                                      .grey.shade300),
                              const SizedBox(
                                  height: 12),
                              Text(
                                  _searchText.isEmpty
                                      ? 'No users found'
                                      : 'No results for "$_searchText"',
                                  style: TextStyle(
                                      color: Colors
                                          .grey.shade400,
                                      fontSize: 16)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadUsers,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                                        16, 0, 16, 16),
                            itemCount:
                                _filteredUsers
                                    .length,
                            itemBuilder:
                                (context, index) {
                              final user =
                                  _filteredUsers[
                                      index];
                              final name =
                                  user['name'] ??
                                      'Unknown';
                              final email =
                                  user['email'] ??
                                      '';
                              final phone =
                                  user['phone'] ??
                                      'N/A';
                              final joined =
                                  _timeAgo(user[
                                      'created_at']);

                              return Container(
                                margin:
                                    const EdgeInsets
                                        .only(
                                            bottom:
                                                10),
                                padding:
                                    const EdgeInsets
                                        .all(14),
                                decoration:
                                    BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              12),
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
                                child: Row(
                                  children: [

                                    // ── Avatar ──
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          kAdminColor
                                              .withOpacity(
                                                  0.1),
                                      child: Text(
                                        name
                                            .isNotEmpty
                                            ? name[0]
                                                .toUpperCase()
                                            : '?',
                                        style:
                                            const TextStyle(
                                          color:
                                              kAdminColor,
                                          fontSize: 20,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                        width: 12),

                                    // ── Info ──
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [

                                          // Name
                                          Text(
                                            name,
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                              fontSize:
                                                  14,
                                              color: Colors
                                                  .black87,
                                            ),
                                          ),

                                          const SizedBox(
                                              height:
                                                  4),

                                          // Email
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .email_outlined,
                                                  size:
                                                      13,
                                                  color: Colors
                                                      .grey
                                                      .shade500),
                                              const SizedBox(
                                                  width:
                                                      4),
                                              Expanded(
                                                child:
                                                    Text(
                                                  email,
                                                  style:
                                                      TextStyle(
                                                    fontSize:
                                                        12,
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
                                              ),
                                            ],
                                          ),

                                          const SizedBox(
                                              height:
                                                  3),

                                          // Phone
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .phone_outlined,
                                                  size:
                                                      13,
                                                  color: Colors
                                                      .grey
                                                      .shade500),
                                              const SizedBox(
                                                  width:
                                                      4),
                                              Text(
                                                phone,
                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      12,
                                                  color: Colors
                                                      .grey
                                                      .shade600,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(
                                              height:
                                                  3),

                                          // Joined
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .access_time,
                                                  size:
                                                      13,
                                                  color: Colors
                                                      .grey
                                                      .shade400),
                                              const SizedBox(
                                                  width:
                                                      4),
                                              Text(
                                                'Joined $joined',
                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      11,
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

                                    // ── Delete ──
                                    IconButton(
                                      icon: const Icon(
                                          Icons
                                              .person_remove_outlined,
                                          color:
                                              Colors.red,
                                          size: 22),
                                      onPressed: () =>
                                          _deleteUser(
                                              user['id'],
                                              name),
                                    ),
                                  ],
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