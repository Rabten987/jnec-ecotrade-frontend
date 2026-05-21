import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'package:flutter/material.dart';

class HomeController extends GetxController {
  final items            = <dynamic>[].obs;
  final categories       = <String>['All'].obs;
  final isLoading        = false.obs;
  final selectedCategory = 'All'.obs;
  final searchText       = ''.obs;
  final unreadCount      = 0.obs;

  // ✅ Timer for periodic notification refresh
  Timer? _notificationTimer;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
    loadItems();
    loadUnreadCount();

    // ✅ Auto-refresh unread count every 30 seconds
    // This ensures buyer sees notification badge update
    // when seller accepts bid even if app is open
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => loadUnreadCount(),
    );
  }

  @override
  void onClose() {
    // ✅ Cancel timer when controller is destroyed
    _notificationTimer?.cancel();
    super.onClose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // ✅ Load categories from backend
  Future<void> loadCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final List<String> loaded = ['All'];
        for (final cat in data) {
          loaded.add(cat['value'].toString());
        }
        categories.value = loaded;
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      categories.value = [
        'All',
        'stationary',
        'clothing',
        'furniture',
        'kitchen_utensils',
        'electronic',
        'miscellaneous',
        'others',
      ];
    }
  }

  Future<void> loadItems() async {
    isLoading.value = true;
    try {
      String url = Constants.productsUrl;

      final params = <String, String>{};

      if (selectedCategory.value != 'All' &&
          selectedCategory.value.isNotEmpty) {
        params['category'] = selectedCategory.value;
      }

      if (searchText.value.isNotEmpty) {
        params['search'] = searchText.value;
      }

      if (params.isNotEmpty) {
        final queryString = params.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url = '$url?$queryString';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawItems = jsonDecode(response.body);
        final now = DateTime.now().toUtc();

        items.value = rawItems.where((item) {
          if (item['status'] == 'sold') return false;

          final auctionEnabled = item['auction_enabled'];
          final isAuction = auctionEnabled == true ||
              auctionEnabled == 1 ||
              auctionEnabled.toString() == 'true';

          if (isAuction && item['auction_ends_at'] != null) {
            try {
              final endsAt =
                  DateTime.parse(item['auction_ends_at']).toUtc();
              if (now.isAfter(endsAt)) return false;
            } catch (_) {}
          }

          return true;
        }).toList();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load items: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
    loadItems();
  }

  void search(String text) {
    searchText.value = text;
    loadItems();
  }

  // ✅ Call this after placing a bid
  void onBidPlaced() {
    loadItems();
  }

  // ✅ Load unread notification count
  Future<void> loadUnreadCount() async {
    try {
      final token = await _getToken();
      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/notifications/unread'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        unreadCount.value = data['count'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }
}