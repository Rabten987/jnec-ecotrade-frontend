import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'package:flutter/material.dart';

class HomeController extends GetxController {
  final items            = <dynamic>[].obs;
  final categories       = <String>['All'].obs; // ✅ Dynamic
  final isLoading        = false.obs;
  final selectedCategory = 'All'.obs;
  final searchText       = ''.obs;
  final unreadCount      = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories(); // ✅ Load categories first
    loadItems();
    loadUnreadCount();
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
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
        final data = jsonDecode(response.body)
            as List<dynamic>;

        // ✅ Always start with 'All'
        final List<String> loaded = ['All'];

        for (final cat in data) {
          loaded.add(cat['value'].toString());
        }

        categories.value = loaded;
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      // ✅ Fallback to defaults if error
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
        params['category'] =
            selectedCategory.value;
      }

      if (searchText.value.isNotEmpty) {
        params['search'] = searchText.value;
      }

      if (params.isNotEmpty) {
        final queryString = params.entries
            .map((e) => '${e.key}=${e.value}')
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
        items.value = jsonDecode(response.body);
      }
    } catch (e) {
      Get.snackbar(
          'Error', 'Failed to load items: $e');
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

  // ✅ Load unread notification count
  Future<void> loadUnreadCount() async {
    try {
      final token    = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/notifications/unread'),
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
      debugPrint(
          'Error loading unread count: $e');
    }
  }
}