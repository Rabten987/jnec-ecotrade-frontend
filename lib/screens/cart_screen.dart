import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/cart_controller.dart';
import 'item_detail_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final _cartController = Get.find<CartController>();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          // ✅ Clear cart button
          Obx(() => _cartController.cartItems.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => Get.dialog(
                    AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16)),
                      title: const Text('Clear Cart'),
                      content: const Text(
                          'Remove all items from cart?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Get.back(),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: Colors
                                      .grey.shade600)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _cartController.clearCart();
                            Get.back();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        8)),
                          ),
                          child: const Text('Clear',
                              style: TextStyle(
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox()),
        ],
      ),
      body: Obx(() {
        if (_cartController.cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 70,
                    color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Your cart is empty',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add items from the home screen',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [

            // ── Cart Items ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount:
                    _cartController.cartItems.length,
                itemBuilder: (context, index) {
                  final item =
                      _cartController.cartItems[index];

                  Uint8List? imageBytes;
                  if (item['image'] != null &&
                      item['image']
                          .toString()
                          .isNotEmpty) {
                    try {
                      imageBytes =
                          base64Decode(item['image']);
                    } catch (_) {}
                  }

                  return GestureDetector(
                    onTap: () => Get.to(
                        () => ItemDetailScreen(
                            item: item)),
                    child: Container(
                      margin: const EdgeInsets.only(
                          bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius:
                            BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [

                          // ── Image ──
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(8),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: imageBytes != null
                                  ? Image.memory(
                                      imageBytes,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: Colors
                                          .grey.shade200,
                                      child: Icon(
                                        Icons
                                            .image_outlined,
                                        color: Colors
                                            .grey.shade400,
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
                                  item['item_name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // ── Price ──
                          Text(
                            'Nu.${item['price']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(width: 8),

                          // ── Remove Button ──
                          GestureDetector(
                            onTap: () => _cartController
                                .removeFromCart(item),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Sub Total ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 24),
              child: Obx(() => SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Sub Total = ${_cartController.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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