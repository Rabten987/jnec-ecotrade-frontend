import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import '../controllers/auth_controller.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String phone;

  const EditProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  // ✅ GetX controller
  final _authController = Get.find<AuthController>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController  =
        TextEditingController(text: widget.name);
    _phoneController =
        TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Name cannot be empty!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.put(
        Uri.parse('${Constants.baseUrl}/update-profile'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name':  _nameController.text,
          'phone': _phoneController.text,
        }),
      );

      final data = jsonDecode(response.body);

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
  // ✅ Update SharedPreferences
  await prefs.setString(
      'user_name', _nameController.text);
  await prefs.setString(
      'user_phone', _phoneController.text);

  // ✅ Update AuthController observables
  _authController.userName.value =
      _nameController.text;
  _authController.userPhone.value =
      _phoneController.text;

      // ✅ Show success dialog instead of snackbar
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle,
                  color: Colors.teal.shade600, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Profile Updated!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your profile has been updated successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back(); // close dialog
                    Get.back(); // go back to profile
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30)),
                  ),
                  child: const Text('OK',
                      style:
                          TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      } else {
        Get.snackbar(
          'Error',
          data['message'] ?? 'Update failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('Edit Profile'),
        // ✅ GetX back
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    child: const Icon(Icons.person,
                        size: 60, color: Colors.grey),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(
                    color: Colors.black54),
                prefixIcon: Icon(Icons.person_outline,
                    color: Colors.teal.shade600),
                enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.black26)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 16),

            // Email (read only)
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email (cannot be changed)',
                labelStyle: const TextStyle(
                    color: Colors.black38),
                hintText: widget.email,
                hintStyle: const TextStyle(
                    color: Colors.black45),
                prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.black38),
                enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.black12)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.black12)),
              ),
            ),

            const SizedBox(height: 16),

            // Phone
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: const TextStyle(
                    color: Colors.black54),
                prefixIcon: Icon(Icons.phone_outlined,
                    color: Colors.teal.shade600),
                enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.black26)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.teal)),
              ),
            ),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}