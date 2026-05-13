import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedController extends GetxController {
  final savedItems = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadSavedItems();
  }

  // ✅ Load saved items from SharedPreferences
  Future<void> loadSavedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('saved_items') ?? '[]';
      savedItems.value = jsonDecode(savedJson);
    } catch (e) {
      debugPrint('Error loading saved items: $e');
    }
  }

  // ✅ Check if item is saved
  bool isSaved(dynamic item) {
    return savedItems.any((s) => s['id'] == item['id']);
  }

  // ✅ Toggle save/unsave
  Future<void> toggleSave(dynamic item) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (isSaved(item)) {
        // Remove from saved
        savedItems.removeWhere((s) => s['id'] == item['id']);
        Get.snackbar(
          'Removed',
          'Item removed from saved!',
          backgroundColor: Colors.grey.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 1),
        );
      } else {
        // Add to saved
        savedItems.add(item);
        Get.snackbar(
          'Saved!',
          'Item added to saved!',
          backgroundColor: Colors.teal.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 1),
        );
      }

      // ✅ Persist to SharedPreferences
      await prefs.setString(
          'saved_items', jsonEncode(savedItems.toList()));
    } catch (e) {
      debugPrint('Error toggling save: $e');
    }
  }

  // ✅ Remove item from saved
  Future<void> removeItem(dynamic item) async {
    final prefs = await SharedPreferences.getInstance();
    savedItems.removeWhere((s) => s['id'] == item['id']);
    await prefs.setString(
        'saved_items', jsonEncode(savedItems.toList()));
    Get.snackbar(
      'Removed',
      'Item removed from saved!',
      backgroundColor: Colors.grey.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}