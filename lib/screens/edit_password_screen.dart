import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';


class EditPasswordScreen extends StatefulWidget {
  const EditPasswordScreen({super.key});

  @override
  State<EditPasswordScreen> createState() =>
      _EditPasswordScreenState();
}

class _EditPasswordScreenState
    extends State<EditPasswordScreen> {
  // ✅ GetX controller
  

  final _currentPasswordController = TextEditingController();
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    // ✅ Validation with GetX snackbar
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill all fields!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_newPasswordController.text !=
        _confirmPasswordController.text) {
      Get.snackbar(
        'Error',
        'New passwords do not match!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // ✅ Password strength check
    if (_newPasswordController.text.length < 8) {
      Get.snackbar('Error',
        'Password must be at least 8 characters!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!_newPasswordController.text
        .contains(RegExp(r'[A-Z]'))) {
      Get.snackbar('Error',
        'Password must contain uppercase letter!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!_newPasswordController.text
        .contains(RegExp(r'[a-z]'))) {
      Get.snackbar('Error',
        'Password must contain lowercase letter!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!_newPasswordController.text
        .contains(RegExp(r'[0-9]'))) {
      Get.snackbar('Error',
        'Password must contain a number!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.put(
        Uri.parse('${Constants.baseUrl}/update-password'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password':      _currentPasswordController.text,
          'password':              _newPasswordController.text,
          'password_confirmation': _confirmPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        // ✅ GetX dialog
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
                  'Password Updated!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your password has been updated successfully.',
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
                        style: TextStyle(
                            color: Colors.white)),
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
        title: const Text('Edit Password'),
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

            // Current Password
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: const TextStyle(
                    color: Colors.black54),
                prefixIcon: Icon(Icons.lock_outline,
                    color: Colors.teal.shade600),
                enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.black26)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.teal)),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() =>
                      _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // New Password
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: const TextStyle(
                    color: Colors.black54),
                prefixIcon: Icon(Icons.lock_outline,
                    color: Colors.teal.shade600),
                enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.black26)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.teal)),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(
                      () => _obscureNew = !_obscureNew),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Confirm New Password
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: const TextStyle(
                    color: Colors.black54),
                prefixIcon: Icon(Icons.lock_outline,
                    color: Colors.teal.shade600),
                enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.black26)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.teal)),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() =>
                      _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Update Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : _updatePassword,
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
                        'Update Password',
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