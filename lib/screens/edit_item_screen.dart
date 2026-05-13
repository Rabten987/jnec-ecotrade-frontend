import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class EditItemScreen extends StatefulWidget {
  final dynamic item;
  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _itemNameController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;
  late TextEditingController _contactController;
  final TextEditingController _minBidController    = TextEditingController();
  final TextEditingController _auctionDaysController = TextEditingController();

  late String _selectedCondition;
  late String _selectedCategory;
  bool        _isLoading       = false;
  bool        _auctionEnabled  = false; // ✅ auction toggle

  Uint8List? _imageBytes;
  String?    _imageBase64;

  final List<String> _conditions = ['new', 'used', 'like_new'];
  final List<String> _categories = [
    'stationary', 'clothing', 'furniture',
    'kitchen_utensils', 'electronic', 'miscellaneous', 'others',
  ];

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController(text: widget.item['item_name'] ?? '');
    _priceController    = TextEditingController(text: widget.item['price'].toString());
    _locationController = TextEditingController(text: widget.item['location'] ?? '');
    _contactController  = TextEditingController(text: widget.item['contact_preference'] ?? '');
    _selectedCondition  = widget.item['condition'] ?? 'used';
    _selectedCategory   = widget.item['category'] ?? 'stationary';

    // ✅ Pre-fill auction fields if already auction item
    final auctionVal   = widget.item['auction_enabled'];
    _auctionEnabled    = auctionVal == true || auctionVal == 1 || auctionVal.toString() == 'true';
    if (widget.item['min_bid_price'] != null) {
      _minBidController.text = widget.item['min_bid_price'].toString();
    }

    if (widget.item['image'] != null && widget.item['image'].toString().isNotEmpty) {
      try {
        _imageBytes  = base64Decode(widget.item['image']);
        _imageBase64 = widget.item['image'];
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _minBidController.dispose();
    _auctionDaysController.dispose();
    super.dispose();
  }

  // ✅ Bhutan phone validation
  bool _isValidBhutanPhone(String phone) {
    if (phone.length != 8) return false;
    return RegExp(r'^(17|77|16|8)\d{6,7}$').hasMatch(phone);
  }

  String _formatLabel(String val) =>
      val[0].toUpperCase() + val.substring(1).replaceAll('_', ' ');

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.teal.shade600),
              title: const Text('Take a Photo'),
              onTap: () { Get.back(); _pickImageFrom(ImageSource.camera); },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.teal.shade600),
              title: const Text('Choose from Gallery'),
              onTap: () { Get.back(); _pickImageFrom(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFrom(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() { _imageBytes = bytes; _imageBase64 = base64Encode(bytes); });
    }
  }

  Future<void> _updateItem() async {
    if (_itemNameController.text.isEmpty || _priceController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill item name and price!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // ✅ Validate phone
    if (_contactController.text.isNotEmpty &&
        !_isValidBhutanPhone(_contactController.text)) {
      Get.snackbar('Invalid Phone',
          'Enter a valid Bhutan number (BMobile: 17/77, TCell: 16/8)',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // ✅ Validate auction fields
    if (_auctionEnabled && _minBidController.text.isEmpty) {
      Get.snackbar('Error', 'Please set a minimum bid price!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final Map<String, dynamic> body = {
        'item_name':          _itemNameController.text,
        'condition':          _selectedCondition,
        'category':           _selectedCategory,
        'price':              double.parse(_priceController.text),
        'location':           _locationController.text,
        'contact_preference': _contactController.text,
        'image':              _imageBase64,
        'auction_enabled':    _auctionEnabled,
      };

      // ✅ Include auction fields if enabled
      if (_auctionEnabled) {
        if (_minBidController.text.isNotEmpty) {
          body['min_bid_price'] = double.parse(_minBidController.text);
        }
        if (_auctionDaysController.text.isNotEmpty) {
          body['auction_duration'] = int.parse(_auctionDaysController.text); // ✅ only if filled
        }
      }
      final response = await http.put(
        Uri.parse('${Constants.baseUrl}/items/${widget.item['id']}'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.teal.shade600, size: 60),
                const SizedBox(height: 16),
                const Text('Item Updated!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _auctionEnabled
                      ? 'Your item is now listed for auction!'
                      : 'Your item has been updated successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Get.back(); Get.back(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          barrierDismissible: false,
        );
      } else {
        final data = jsonDecode(response.body);
        Get.snackbar('Error', data['message'] ?? 'Failed to update item',
            backgroundColor: Colors.red, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('Edit Item'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Image ──
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity, height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain,
                            width: double.infinity))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Tap to change image', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Item Name ──
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: 'Item name', labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 16),

            // ── Condition ──
            DropdownButtonFormField<String>(
              value: _selectedCondition,
              decoration: const InputDecoration(
                labelText: 'Condition', labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
              ),
              items: _conditions.map((c) => DropdownMenuItem(
                  value: c, child: Text(_formatLabel(c)))).toList(),
              onChanged: (val) => setState(() => _selectedCondition = val!),
            ),

            const SizedBox(height: 16),

            // ── Category ──
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category', labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
              ),
              items: _categories.map((c) => DropdownMenuItem(
                  value: c, child: Text(_formatLabel(c)))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),

            const SizedBox(height: 16),

            // ── Price ──
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (Nu)', labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 16),

            // ── Location ──
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location', labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Contact with Bhutan validation
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Contact',
                labelStyle: const TextStyle(color: Colors.black54),
                counterText: '',
                helperText: _contactController.text.isEmpty
                    ? 'BMobile: 17/77, TCell: 16/8'
                    : _isValidBhutanPhone(_contactController.text)
                        ? '✅ Valid Bhutan number'
                        : 'Invalid Bhutan number',
                helperStyle: TextStyle(
                    fontSize: 11,
                    color: _contactController.text.isNotEmpty &&
                            _isValidBhutanPhone(_contactController.text)
                        ? Colors.green
                        : Colors.black45),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: _contactController.text.isNotEmpty &&
                                !_isValidBhutanPhone(_contactController.text)
                            ? Colors.red
                            : Colors.black26)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: _contactController.text.isNotEmpty &&
                                !_isValidBhutanPhone(_contactController.text)
                            ? Colors.red
                            : Colors.teal)),
              ),
            ),

            const SizedBox(height: 24),

            // ✅ Auction Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _auctionEnabled ? Colors.teal.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _auctionEnabled ? Colors.teal.shade300 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Toggle row
                  Row(
                    children: [
                      Icon(Icons.gavel,
                          color: _auctionEnabled ? Colors.teal.shade600 : Colors.grey, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Enable Auction',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              _auctionEnabled
                                  ? 'Buyers can bid on this item'
                                  : 'Turn on to sell via auction',
                              style: const TextStyle(fontSize: 11, color: Colors.black45),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _auctionEnabled,
                        activeColor: Colors.teal.shade600,
                        onChanged: (val) => setState(() => _auctionEnabled = val),
                      ),
                    ],
                  ),

                  // ✅ Auction fields — shown when enabled
                  if (_auctionEnabled) ...[
                    const SizedBox(height: 16),

                    TextField(
                      controller: _minBidController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Minimum Bid Price (Nu)',
                        labelStyle: TextStyle(color: Colors.teal.shade700),
                        hintText: 'e.g. 100',
                        hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade600)),
                        prefixIcon: Icon(Icons.currency_rupee,
                            color: Colors.teal.shade600, size: 18),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _auctionDaysController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Auction Duration (days)',
                        labelStyle: TextStyle(color: Colors.teal.shade700),
                        hintText: 'e.g. 3  (max 30 days)',
                        hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade600)),
                        prefixIcon: Icon(Icons.timer_outlined,
                            color: Colors.teal.shade600, size: 18),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Auction closes after the set number of days. Winner is the highest bidder.',
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                          )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Update Button ──
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _auctionEnabled ? 'Update & Enable Auction' : 'Update Item',
                        style: const TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}