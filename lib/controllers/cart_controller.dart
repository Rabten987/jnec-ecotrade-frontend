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

  // ✅ Load cart from SharedPreferences
  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items') ?? '[]';
      cartItems.value = jsonDecode(cartJson);
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  // ✅ Check if item is in cart
  bool isInCart(dynamic item) {
    return cartItems.any((c) => c['id'] == item['id']);
  }

  // ✅ Add to cart
  Future<void> addToCart(dynamic item) async {
    if (isInCart(item)) {
      Get.snackbar(
        'Already in Cart',
        'This item is already in your cart!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    cartItems.add(item);
    await _saveCart();

    Get.snackbar(
      'Added to Cart!',
      '${item['item_name']} added to cart!',
      backgroundColor: Colors.teal.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  // ✅ Remove from cart
  Future<void> removeFromCart(dynamic item) async {
    cartItems.removeWhere((c) => c['id'] == item['id']);
    await _saveCart();

    Get.snackbar(
      'Removed',
      '${item['item_name']} removed from cart!',
      backgroundColor: Colors.grey.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  // ✅ Clear cart
  Future<void> clearCart() async {
    cartItems.clear();
    await _saveCart();
  }

  // ✅ Get total price
  double get totalPrice {
    return cartItems.fold(0, (sum, item) {
      final price = double.tryParse(
              item['price'].toString()) ??
          0;
      return sum + price;
    });
  }

  // ✅ Save cart to SharedPreferences
  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'cart_items', jsonEncode(cartItems.toList()));
  }
}