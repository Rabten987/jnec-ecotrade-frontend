import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/image_helper.dart';

class EditItemScreen extends StatefulWidget {
  final dynamic item;
  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _itemNameController;
  late TextEditingController _locationController;
  late TextEditingController _contactController;
  final TextEditingController _minBidController      = TextEditingController();
  final TextEditingController _auctionDaysController = TextEditingController();

  late String _selectedCondition;
  late String _selectedCategory;
  bool _isLoading = false;

  // ✅ Store the selected end date for display
  DateTime? _selectedEndDate;

  // ✅ Multiple images support
  final List<Uint8List> _imageBytesList  = [];
  final List<String>    _imageBase64List = [];
  static const int      _maxImages       = 4;

  final List<String> _conditions = ['new', 'used', 'like_new'];
  final List<String> _categories = [
    'stationary', 'clothing', 'furniture',
    'kitchen_utensils', 'electronic', 'miscellaneous', 'others',
  ];

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController(text: widget.item['item_name'] ?? '');
    _locationController = TextEditingController(text: widget.item['location'] ?? '');
    _contactController  = TextEditingController(text: widget.item['contact_preference'] ?? '');
    _selectedCondition  = widget.item['condition'] ?? 'used';
    _selectedCategory   = widget.item['category'] ?? 'stationary';

    // ✅ Min bid is now the only price field — prefill from min_bid_price,
    // falling back to price if min_bid_price isn't set yet
    if (widget.item['min_bid_price'] != null) {
      _minBidController.text = widget.item['min_bid_price'].toString();
    } else if (widget.item['price'] != null) {
      _minBidController.text = widget.item['price'].toString();
    }

    // ✅ Preload existing auction_ends_at as selected date
    if (widget.item['auction_ends_at'] != null) {
      try {
        _selectedEndDate = DateTime.parse(widget.item['auction_ends_at']).toLocal();
        final now  = DateTime.now();
        final days = _selectedEndDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
        if (days > 0) {
          _auctionDaysController.text = days.toString();
        }
      } catch (_) {}
    }

    // ✅ Load existing images using ImageHelper
    final existingImages = ImageHelper.getImages(widget.item['image']);
    final rawImage       = widget.item['image']?.toString() ?? '';

    if (existingImages.isNotEmpty) {
      _imageBytesList.addAll(existingImages);
      if (rawImage.startsWith('[')) {
        try {
          final decoded = jsonDecode(rawImage) as List;
          _imageBase64List.addAll(decoded.map((e) => e.toString()));
        } catch (_) {}
      } else if (rawImage.isNotEmpty) {
        _imageBase64List.add(rawImage);
      }
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _minBidController.dispose();
    _auctionDaysController.dispose();
    super.dispose();
  }

  bool _isValidBhutanPhone(String phone) {
    if (phone.length != 8) return false;
    return RegExp(r'^(17|77|16|8\d)\d{6}$').hasMatch(phone);
  }

  String _formatLabel(String val) =>
      val[0].toUpperCase() + val.substring(1).replaceAll('_', ' ');

  Future<void> _pickEndDate() async {
    final now     = DateTime.now();
    final maxDate = now.add(const Duration(days: 30));

    final initialDate = (_selectedEndDate != null && _selectedEndDate!.isAfter(now))
        ? _selectedEndDate!
        : now.add(const Duration(days: 3));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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
      final days = picked.difference(DateTime(now.year, now.month, now.day)).inDays;
      setState(() {
        _selectedEndDate = picked;
        _auctionDaysController.text = days.toString();
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_imageBytesList.length >= _maxImages) {
      Get.snackbar('Limit Reached', 'Maximum $_maxImages photos allowed.',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: source, maxWidth: 800, imageQuality: 70);
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
        child: Wrap(
          children: [
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
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _imageBytesList.removeAt(index);
      _imageBase64List.removeAt(index);
    });
  }

  Future<void> _updateItem() async {
    if (_itemNameController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill item name!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (_contactController.text.isNotEmpty &&
        !_isValidBhutanPhone(_contactController.text)) {
      Get.snackbar('Invalid Phone',
          'Enter a valid Bhutan number (BMobile: 17/77, TCell: 16/8x)',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (_minBidController.text.isEmpty) {
      Get.snackbar('Error', 'Please set a minimum bid price!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final minBid = double.tryParse(_minBidController.text);
    if (minBid == null || minBid <= 0) {
      Get.snackbar('Error', 'Minimum bid price must be greater than zero!',
          backgroundColor: Colors.orange, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      String? imageValue;
      if (_imageBase64List.length == 1) {
        imageValue = _imageBase64List.first;
      } else if (_imageBase64List.length > 1) {
        imageValue = jsonEncode(_imageBase64List);
      }

      final Map<String, dynamic> body = {
        'item_name':          _itemNameController.text,
        'condition':          _selectedCondition,
        'category':           _selectedCategory,
        'price':              minBid,
        'location':           _locationController.text,
        'contact_preference': _contactController.text,
        'auction_enabled':    true,
        'min_bid_price':      minBid,
      };

      if (imageValue != null) body['image'] = imageValue;

      if (_auctionDaysController.text.isNotEmpty) {
        body['auction_duration'] = int.parse(_auctionDaysController.text);
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
                const Text(
                  'Your auction item has been updated successfully.',
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

            // ── Photos Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Photos (${_imageBytesList.length}/$_maxImages)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                if (_imageBytesList.length < _maxImages)
                  TextButton.icon(
                    onPressed: _showImagePicker,
                    icon: Icon(Icons.add_photo_alternate, color: Colors.teal.shade600, size: 18),
                    label: Text('Add Photo', style: TextStyle(color: Colors.teal.shade600, fontSize: 13)),
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
                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('Tap to add photos',
                          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
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
                  itemCount: _imageBytesList.length + (_imageBytesList.length < _maxImages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _imageBytesList.length) {
                      return GestureDetector(
                        onTap: _showImagePicker,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.teal.shade300, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.teal.shade50,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.teal.shade600, size: 28),
                              const SizedBox(height: 4),
                              Text('Add', style: TextStyle(color: Colors.teal.shade600, fontSize: 12)),
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
                                color: index == 0 ? Colors.teal.shade400 : Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_imageBytesList[index], fit: BoxFit.cover),
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
                              child: const Text('Main', textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        Positioned(
                          top: 0, right: 8,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
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
                child: Text('First photo is the main display image. Tap x to remove.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
                counterText: '${_contactController.text.length}/8',
                counterStyle: const TextStyle(fontSize: 11),
                helperText: _contactController.text.isEmpty
                    ? 'BMobile: 17/77, TCell: 16/8x'
                    : _isValidBhutanPhone(_contactController.text)
                        ? 'Valid Bhutan number'
                        : 'Invalid — must start with 17, 77, 16, or 8x',
                helperStyle: TextStyle(
                    fontSize: 11,
                    color: _contactController.text.isNotEmpty &&
                            _isValidBhutanPhone(_contactController.text)
                        ? Colors.green
                        : _contactController.text.length == 8
                            ? Colors.red
                            : Colors.black45),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: _contactController.text.length == 8 &&
                                !_isValidBhutanPhone(_contactController.text)
                            ? Colors.red
                            : _contactController.text.length == 8 &&
                                    _isValidBhutanPhone(_contactController.text)
                                ? Colors.green
                                : Colors.black26)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: _contactController.text.length == 8 &&
                                !_isValidBhutanPhone(_contactController.text)
                            ? Colors.red
                            : Colors.teal)),
                suffixIcon: _contactController.text.length == 8
                    ? Icon(
                        _isValidBhutanPhone(_contactController.text)
                            ? Icons.check_circle : Icons.cancel,
                        color: _isValidBhutanPhone(_contactController.text)
                            ? Colors.green : Colors.red,
                        size: 20)
                    : null,
              ),
            ),

            const SizedBox(height: 24),

            // ── Auction Settings (always shown — no toggle, matches post_screen) ──
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

                  Row(
                    children: [
                      Icon(Icons.gavel, color: Colors.teal.shade600, size: 22),
                      const SizedBox(width: 10),
                      Text('Auction Settings',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.teal.shade700)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Minimum Bid Price (only price field) ──
                  TextField(
                    controller: _minBidController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
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

                  // ✅ Calendar date picker — same as post_screen
                  GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                          final days = int.tryParse(_auctionDaysController.text) ?? 0;
                                          final endDate = DateTime.now().add(Duration(days: days));
                                          return '${endDate.day.toString().padLeft(2, '0')}/'
                                              '${endDate.month.toString().padLeft(2, '0')}/'
                                              '${endDate.year}  ($days days from now)';
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
                          Icon(Icons.arrow_drop_down, color: Colors.teal.shade600),
                        ],
                      ),
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
                          'Auction closes on the selected date. Winner is the highest bidder.',
                          style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

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
                    : const Text(
                        'Update Auction Item',
                        style: TextStyle(color: Colors.white, fontSize: 16,
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