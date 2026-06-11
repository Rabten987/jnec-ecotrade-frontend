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

  String  _selectedCondition = 'used';
  String? _selectedCategory;
  bool    _isLoading         = false;
  bool    _categoriesLoading = true;

  // ✅ Multiple images — max 4
  final List<Uint8List> _imageBytesList  = [];
  final List<String>    _imageBase64List = [];
  static const int      _maxImages       = 4;

  List<String>       _categories = [];
  final List<String> _conditions = ['new', 'used', 'like_new'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _autoFillContact();
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

  Future<void> _autoFillContact() async {
    try {
      final authController = Get.find<AuthController>();
      final phone = authController.userPhone.value;
      if (phone.isNotEmpty) setState(() => _contactController.text = phone);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      if (phone.isNotEmpty) setState(() => _contactController.text = phone);
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
      _categories       = ['stationary', 'clothing', 'furniture', 'kitchen_utensils', 'electronic', 'miscellaneous', 'others'];
      _selectedCategory ??= _categories.first;
    });
  }

  bool _isValidBhutanPhone(String phone) {
    if (phone.length != 8) return false;
    return RegExp(r'^(17|77|16|8\d)\d{6}$').hasMatch(phone);
  }

  String _phoneHelperText(String phone) {
    if (phone.isEmpty) return 'BMobile: 17/77, TCell: 16/8x — 8 digits';
    if (phone.length < 8) return 'Enter ${8 - phone.length} more digit(s)';
    if (_isValidBhutanPhone(phone)) return 'Valid Bhutan number';
    return 'Invalid — must start with 17, 77, 16, or 8x';
  }

  Color _phoneHelperColor(String phone) {
    if (phone.isEmpty) return Colors.black45;
    if (phone.length == 8 && _isValidBhutanPhone(phone)) return Colors.green;
    if (phone.length == 8) return Colors.red;
    return Colors.black45;
  }

  Color _phoneBorderColor(String phone) {
    if (phone.length == 8 && _isValidBhutanPhone(phone)) return Colors.green;
    if (phone.length == 8 && !_isValidBhutanPhone(phone)) return Colors.red;
    return Colors.black26;
  }

  String _formatLabel(String val) =>
      val[0].toUpperCase() + val.substring(1).replaceAll('_', ' ');

  Future<void> _pickImage(ImageSource source) async {
    if (_imageBytesList.length >= _maxImages) {
      Get.snackbar('Limit Reached', 'Maximum $_maxImages photos allowed.',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 70);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytesList.add(bytes);
          _imageBase64List.add(base64Encode(bytes));
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showImagePicker() {
    if (_imageBytesList.length >= _maxImages) {
      Get.snackbar('Limit Reached', 'Maximum $_maxImages photos allowed.',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Add Photo (${_imageBytesList.length}/$_maxImages)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: Colors.teal.shade600),
            title: const Text('Choose from Gallery'),
            onTap: () { Get.back(); _pickImage(ImageSource.gallery); },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt, color: Colors.teal.shade600),
            title: const Text('Take a Photo'),
            onTap: () { Get.back(); _pickImage(ImageSource.camera); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _imageBytesList.removeAt(index);
      _imageBase64List.removeAt(index);
    });
  }

  Future<void> _postItem() async {
    if (_itemNameController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill item name!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_priceController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill price!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_contactController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill contact number!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM); return;
    }
    if (!_isValidBhutanPhone(_contactController.text)) {
      Get.snackbar('Invalid Phone Number',
          'Enter a valid Bhutan number:\n- BMobile: 17xxxxxx or 77xxxxxx\n- TCell: 16xxxxxx or 8xxxxxxx',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4)); return;
    }
    if (_selectedCategory == null) {
      Get.snackbar('Error', 'Please select a category!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_minBidController.text.isEmpty) {
      Get.snackbar('Error', 'Please set a minimum bid price!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM); return;
    }
    if (_auctionDaysController.text.isEmpty) {
      Get.snackbar('Error', 'Please select an auction end date!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM); return;
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
        'auction_enabled':    true,  // ✅ always auction
        'min_bid_price':      double.parse(_minBidController.text),
        'auction_duration':   int.parse(_auctionDaysController.text),
      };

      // ✅ Send images as JSON array for multiple, single string for one
      if (_imageBase64List.length == 1) {
        body['image'] = _imageBase64List.first;
      } else if (_imageBase64List.length > 1) {
        body['image'] = jsonEncode(_imageBase64List);
      }

      final response = await http.post(
        Uri.parse(Constants.productsUrl),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
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
                const Text('Item Posted!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Your item is listed for auction!\nBidding starts now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Get.back(); Get.back(); },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
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
            backgroundColor: Colors.red, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = _contactController.text;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('List an Item for Auction'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Get.to(() => const NotificationsScreen())),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Auction banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.gavel, color: Colors.teal.shade600, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All items are listed as auctions. Buyers bid and the highest bidder wins.',
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Photos Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Photos (${_imageBytesList.length}/$_maxImages)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87)),
                if (_imageBytesList.length < _maxImages)
                  TextButton.icon(
                    onPressed: _showImagePicker,
                    icon: Icon(Icons.add_photo_alternate,
                        color: Colors.teal.shade600, size: 18),
                    label: Text('Add Photo',
                        style: TextStyle(color: Colors.teal.shade600, fontSize: 13)),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            if (_imageBytesList.isEmpty)
              GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  width: double.infinity, height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('Tap to add photos',
                          style: TextStyle(
                              color: Colors.black54, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Up to $_maxImages photos',
                          style: const TextStyle(color: Colors.black38, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageBytesList.length +
                      (_imageBytesList.length < _maxImages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _imageBytesList.length) {
                      return GestureDetector(
                        onTap: _showImagePicker,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.teal.shade300, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.teal.shade50,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.teal.shade600, size: 28),
                              const SizedBox(height: 4),
                              Text('Add',
                                  style: TextStyle(
                                      color: Colors.teal.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Container(
                          width: 100, height: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: index == 0
                                    ? Colors.teal.shade400
                                    : Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_imageBytesList[index],
                                fit: BoxFit.cover),
                          ),
                        ),
                        if (index == 0)
                          Positioned(
                            bottom: 0, left: 0, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade600.withOpacity(0.85),
                                borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8)),
                              ),
                              child: const Text('Main',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        Positioned(
                          top: 0, right: 8,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            if (_imageBytesList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'First photo is the main display image. Tap x to remove.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ),

            const SizedBox(height: 20),

            // ── Item Name ──
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 16),

            // ── Condition ──
            DropdownButtonFormField<String>(
              value: _selectedCondition,
              decoration: const InputDecoration(
                labelText: 'Condition',
                labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal)),
              ),
              items: _conditions
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(_formatLabel(c))))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCondition = val!),
            ),

            const SizedBox(height: 16),

            // ── Category ──
            _categoriesLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.teal)),
                      SizedBox(width: 10),
                      Text('Loading categories...',
                          style:
                              TextStyle(color: Colors.black45, fontSize: 13)),
                    ]))
                : DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: Colors.black54),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black26)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal)),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(_formatLabel(c))))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),

            const SizedBox(height: 16),

            // ── Price ──
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Starting Price (Nu)',
                labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 16),

            // ── Location ──
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 16),

            // ── Contact ──
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
                counterText: '${phone.length}/8',
                counterStyle: TextStyle(
                    fontSize: 11,
                    color: phone.length == 8 ? Colors.black54 : Colors.black38),
                helperText: _phoneHelperText(phone),
                helperStyle:
                    TextStyle(fontSize: 11, color: _phoneHelperColor(phone)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _phoneBorderColor(phone))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _phoneBorderColor(phone))),
                suffixIcon: phone.length == 8
                    ? Icon(
                        _isValidBhutanPhone(phone)
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _isValidBhutanPhone(phone)
                            ? Colors.green
                            : Colors.red,
                        size: 20)
                    : null,
              ),
            ),

            const SizedBox(height: 24),

            // ── Auction Fields (always visible) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Section header
                  Row(
                    children: [
                      Icon(Icons.gavel, color: Colors.teal.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text('Auction Settings',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.teal.shade700)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Minimum Bid Price ──
                  TextField(
                    controller: _minBidController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Minimum Bid Price (Nu)',
                      labelStyle: TextStyle(color: Colors.teal.shade700),
                      hintText: 'e.g. 100',
                      hintStyle:
                          const TextStyle(color: Colors.black38, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal.shade300)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal.shade600)),
                      prefixIcon: Icon(Icons.currency_rupee,
                          color: Colors.teal.shade600, size: 18),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Auction End Date ──
                  GestureDetector(
                    onTap: () async {
                      final now     = DateTime.now();
                      final maxDate = now.add(const Duration(days: 30));
                      final picked  = await showDatePicker(
                        context: context,
                        initialDate: now.add(const Duration(days: 3)),
                        firstDate: now.add(const Duration(days: 1)),
                        lastDate: maxDate,
                        helpText: 'Select Auction End Date',
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.teal.shade600,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black87,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        final days = picked
                            .difference(DateTime(now.year, now.month, now.day))
                            .inDays;
                        setState(() => _auctionDaysController.text = days.toString());
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.teal.shade600, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Auction End Date',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal.shade600,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  _auctionDaysController.text.isEmpty
                                      ? 'Tap to select end date'
                                      : () {
                                          final days = int.tryParse(
                                                  _auctionDaysController.text) ??
                                              3;
                                          final endDate = DateTime.now()
                                              .add(Duration(days: days));
                                          return '${endDate.day.toString().padLeft(2, '0')}/'
                                              '${endDate.month.toString().padLeft(2, '0')}/'
                                              '${endDate.year}  ($days days)';
                                        }(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: _auctionDaysController.text.isEmpty
                                        ? Colors.black38
                                        : Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_drop_down,
                              color: Colors.teal.shade600),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Auction closes on the selected date. The highest bidder wins automatically.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.teal.shade700)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Post Button ──
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _postItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post for Auction',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}