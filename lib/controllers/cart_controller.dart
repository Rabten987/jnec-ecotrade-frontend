import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartController extends GetxController {
  final cartItems = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadCart();
  }

  Future<void> loadCart() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items') ?? '[]';
      cartItems.value = jsonDecode(cartJson);
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  bool isInCart(dynamic item) {
    return cartItems.any((c) => c['id'] == item['id']);
  }

  Future<void> addToCart(dynamic item) async {
    if (isInCart(item)) {
      Get.snackbar(
        'Already in Wishlist',
        '${item['item_name']} is already in your wishlist!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    cartItems.add(item);
    await _saveCart();

    Get.snackbar(
      'Added to Wishlist!',
      '${item['item_name']} added to wishlist!',
      backgroundColor: Colors.teal.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  Future<void> removeFromCart(dynamic item) async {
    cartItems.removeWhere((c) => c['id'] == item['id']);
    await _saveCart();

    Get.snackbar(
      'Removed from Wishlist',
      '${item['item_name']} removed from wishlist!',
      backgroundColor: Colors.grey.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  Future<void> clearCart() async {
    cartItems.clear();
    await _saveCart();
  }

  double get totalPrice {
    return cartItems.fold(0, (sum, item) {
      final price = double.tryParse(item['price'].toString()) ?? 0;
      return sum + price;
    });
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart_items', jsonEncode(cartItems.toList()));
  }
}