import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'notifications_screen.dart';
import 'package:flutter/services.dart';
import '../controllers/home_controller.dart';
import '../controllers/auth_controller.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _itemNameController    = TextEditingController();
  final _priceController       = TextEditingController();
  final _locationController    = TextEditingController();
  final _contactController     = TextEditingController();
  final _minBidController      = TextEditingController();
  final _auctionDaysController = TextEditingController();

  String     _selectedCondition = 'used';
  String?    _selectedCategory;
  bool       _isLoading         = false;
  bool       _categoriesLoading = true;
  bool       _auctionEnabled    = false;
  Uint8List? _imageBytes;
  String?    _imageBase64;

  List<String> _categories = [];
  final List<String> _conditions = ['new', 'used', 'like_new'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _autoFillContact(); // ✅ auto-fill phone from profile
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

  // ✅ Auto-fill contact from user's saved phone number
  Future<void> _autoFillContact() async {
    try {
      final authController = Get.find<AuthController>();
      final phone = authController.userPhone.value;
      if (phone.isNotEmpty) {
        setState(() => _contactController.text = phone);
      }
    } catch (_) {
      // fallback — read from prefs
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      if (phone.isNotEmpty) {
        setState(() => _contactController.text = phone);
      }
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/categories'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data   = jsonDecode(response.body) as List<dynamic>;
        final loaded = data.map((cat) => cat['value'].toString()).toList();
        setState(() {
          _categories       = loaded;
          _selectedCategory = loaded.contains(_selectedCategory)
              ? _selectedCategory
              : (loaded.isNotEmpty ? loaded.first : null);
        });
      } else {
        _useFallbackCategories();
      }
    } catch (e) {
      _useFallbackCategories();
    } finally {
      setState(() => _categoriesLoading = false);
    }
  }

  void _useFallbackCategories() {
    setState(() {
      _categories = ['stationary','clothing','furniture','kitchen_utensils','electronic','miscellaneous','others'];
      _selectedCategory ??= _categories.first;
    });
  }

  // ✅ Bhutan phone validation
  bool _isValidBhutanPhone(String phone) {
    if (phone.length != 8) return false;
    return RegExp(r'^(17|77|16|8)\d{6,7}$').hasMatch(phone);
  }

  String _formatLabel(String val) =>
      val[0].toUpperCase() + val.substring(1).replaceAll('_', ' ');

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.teal.shade600),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Get.back();
                final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() { _imageBytes = bytes; _imageBase64 = base64Encode(bytes); });
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.teal.shade600),
              title: const Text('Take a Photo'),
              onTap: () async {
                Get.back();
                final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() { _imageBytes = bytes; _imageBase64 = base64Encode(bytes); });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postItem() async {
    if (_itemNameController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill item name!', backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_priceController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill price!', backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_contactController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill contact number!', backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM); return;
    }
    // ✅ Bhutan phone validation
    if (!_isValidBhutanPhone(_contactController.text)) {
      Get.snackbar('Invalid Phone', 'Enter a valid Bhutan number (BMobile: 17/77, TCell: 16/8)',
          backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_selectedCategory == null) {
      Get.snackbar('Error', 'Please select a category!', backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_auctionEnabled && _minBidController.text.isEmpty) {
      Get.snackbar('Error', 'Please set a minimum bid price!', backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_auctionEnabled && _auctionDaysController.text.isEmpty) {
      Get.snackbar('Error', 'Please set auction duration in days!', backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM); return;
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

      if (_auctionEnabled) {
        body['min_bid_price']    = double.parse(_minBidController.text);
        body['auction_duration'] = int.parse(_auctionDaysController.text);
      }

      final response = await http.post(
        Uri.parse(Constants.productsUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        try {
          final hc = Get.find<HomeController>();
          hc.loadUnreadCount();
          hc.loadCategories();
        } catch (_) {}

        Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.teal.shade600, size: 60),
                const SizedBox(height: 16),
                const Text('Item Posted!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _auctionEnabled
                      ? 'Your item is listed for auction!\nBidding starts now.'
                      : 'Your item has been posted successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Get.back(); Get.back(); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          barrierDismissible: false,
        );
      } else {
        Get.snackbar('Error', data['message'] ?? 'Failed to post item',
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('List an item'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Get.to(() => const NotificationsScreen())),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Upload Image ──
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 150, maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _imageBytes != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain, width: double.infinity))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Upload Images', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 4),
                          const Text('Add photos of your item', style: TextStyle(color: Colors.black38, fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: _pickImage,
                                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.teal.shade600)),
                                child: Text('Select Images', style: TextStyle(color: Colors.teal.shade600)),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.camera_alt_outlined, color: Colors.black45),
                            ],
                          ),
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
              items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(_formatLabel(c)))).toList(),
              onChanged: (val) => setState(() => _selectedCondition = val!),
            ),

            const SizedBox(height: 16),

            // ── Category ──
            _categoriesLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)),
                      SizedBox(width: 10),
                      Text('Loading categories...', style: TextStyle(color: Colors.black45, fontSize: 13)),
                    ]),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category', labelStyle: TextStyle(color: Colors.black54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(_formatLabel(c)))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
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

            // ✅ Contact — auto-filled from profile, editable, Bhutan validation
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Contact Number',
                labelStyle: const TextStyle(color: Colors.black54),
                hintText: 'e.g. 77123456',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
                counterText: '',
                helperStyle: TextStyle(
                    fontSize: 11,
                    color: _contactController.text.length == 8 && _isValidBhutanPhone(_contactController.text)
                        ? Colors.green
                        : Colors.black45),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 24),

            // ✅ Auction Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _auctionEnabled ? Colors.teal.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _auctionEnabled ? Colors.teal.shade300 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel, color: _auctionEnabled ? Colors.teal.shade600 : Colors.grey, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enable Auction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Buyers bid on your item. Highest bid wins when auction ends.',
                                style: TextStyle(fontSize: 11, color: Colors.black45)),
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
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal.shade300)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal.shade600)),
                        prefixIcon: Icon(Icons.currency_rupee, color: Colors.teal.shade600, size: 18),
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
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal.shade300)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal.shade600)),
                        prefixIcon: Icon(Icons.timer_outlined, color: Colors.teal.shade600, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(8)),
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

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _postItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_auctionEnabled ? 'Post for Auction' : 'Post Item',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}