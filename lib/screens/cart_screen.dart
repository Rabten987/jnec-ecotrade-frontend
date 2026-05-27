import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/cart_controller.dart';
import '../utils/image_helper.dart';
import 'item_detail_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('My Wishlist', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          Obx(() => cartController.cartItems.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => Get.dialog(
                    AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Clear Wishlist'),
                      content: const Text('Remove all items from wishlist?'),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                        ElevatedButton(
                          onPressed: () { cartController.clearCart(); Get.back(); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Clear', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox()),
        ],
      ),
      body: Obx(() {
        if (cartController.cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 70, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Your wishlist is empty',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Add items from the home screen',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartController.cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartController.cartItems[index];
                  // ✅ Use ImageHelper to handle single or JSON array images
                  final Uint8List? imageBytes = ImageHelper.getFirstImage(item['image']);

                  return GestureDetector(
                    onTap: () => Get.to(() => ItemDetailScreen(item: item)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          // ── Image ──
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 60, height: 60,
                              child: imageBytes != null
                                  ? Image.memory(imageBytes, fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.grey.shade200,
                                      child: Icon(Icons.image_outlined, color: Colors.grey.shade400)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ── Info ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['item_name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('Nu. ${item['price']}',
                                    style: TextStyle(color: Colors.teal.shade600,
                                        fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                          // ── Remove Button ──
                          GestureDetector(
                            onTap: () => cartController.removeFromCart(item),
                            child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Total ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Obx(() => SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    'Total = Nu. ${cartController.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )),
            ),
          ],
        );
      }),
    );
  }
}