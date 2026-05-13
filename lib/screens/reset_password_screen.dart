import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  int _currentStep = 1;

  final _contactController     = TextEditingController();
  final _otpController         = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading       = false;

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // ✅ Password strength helpers
  Map<String, bool> _getPasswordChecks(String password) {
    return {
      'min8':      password.length >= 8,
      'uppercase': password.contains(RegExp(r'[A-Z]')),
      'lowercase': password.contains(RegExp(r'[a-z]')),
      'number':    password.contains(RegExp(r'[0-9]')),
    };
  }

  int _getStrengthLevel(String password) {
    final checks = _getPasswordChecks(password);
    return checks.values.where((v) => v).length;
  }

  Color _getStrengthColor(int level) {
    switch (level) {
      case 1:  return Colors.red;
      case 2:  return Colors.orange;
      case 3:  return Colors.yellow.shade700;
      case 4:  return Colors.green;
      default: return Colors.grey.shade300;
    }
  }

  String _getStrengthLabel(int level) {
    switch (level) {
      case 1:  return 'Weak';
      case 2:  return 'Fair';
      case 3:  return 'Good';
      case 4:  return 'Strong ✅';
      default: return '';
    }
  }

  Widget _buildPasswordStrength(String password) {
    final checks = _getPasswordChecks(password);
    final level  = _getStrengthLevel(password);
    final color  = _getStrengthColor(level);
    final label  = _getStrengthLabel(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: index < level
                      ? color
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _checkItem('At least 8 characters',   checks['min8']!),
        _checkItem('Uppercase letter (A-Z)',   checks['uppercase']!),
        _checkItem('Lowercase letter (a-z)',   checks['lowercase']!),
        _checkItem('Number (0-9)',             checks['number']!),
      ],
    );
  }

  Widget _checkItem(String text, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: passed ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: passed
                  ? Colors.green
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Step 1 - Send OTP
  Future<void> _sendOtp() async {
    if (_contactController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter your email or phone number!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final contact = _contactController.text.trim();
    final isEmail = contact.contains('@');

    if (!isEmail) {
      final bhutanPhone = RegExp(r'^[123789]\d{7}$');
      if (!bhutanPhone.hasMatch(contact)) {
        Get.snackbar(
          'Invalid Phone',
          'Please enter a valid Bhutan phone number (8 digits)',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({'contact': contact}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        Get.snackbar(
          'OTP Sent! ✅',
          isEmail
              ? 'OTP sent to your email inbox!'
              : 'OTP sent to +975$contact via SMS!',
          backgroundColor: Colors.teal.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        setState(() => _currentStep = 2);
      } else {
        Get.snackbar(
          'Error',
          data['message'] ?? 'Failed to send OTP',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Step 2 - Verify OTP
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter the OTP code!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({
          'contact': _contactController.text.trim(),
          'code':    _otpController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() => _currentStep = 3);
      } else {
        Get.snackbar(
          'Error',
          data['message'] ?? 'Invalid OTP!',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Step 3 - Reset Password
  Future<void> _resetPassword() async {
    if (_passwordController.text.isEmpty ||
        _confirmPassController.text.isEmpty) {
      Get.snackbar(
        'Error', 'Please fill all fields!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_passwordController.text !=
        _confirmPassController.text) {
      Get.snackbar(
        'Error', 'Passwords do not match!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // ✅ Check password strength
    final checks =
        _getPasswordChecks(_passwordController.text);

    if (!checks['min8']!) {
      Get.snackbar(
        'Error', 'Password must be at least 8 characters!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!checks['uppercase']!) {
      Get.snackbar(
        'Error',
        'Password must contain at least one uppercase letter!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!checks['lowercase']!) {
      Get.snackbar(
        'Error',
        'Password must contain at least one lowercase letter!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!checks['number']!) {
      Get.snackbar(
        'Error',
        'Password must contain at least one number!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            '${Constants.baseUrl}/reset-password-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({
          'contact':               _contactController.text.trim(),
          'code':                  _otpController.text.trim(),
          'password':              _passwordController.text,
          'password_confirmation': _confirmPassController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    color: Colors.teal.shade600, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'Password Reset!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your password has been reset successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.offAll(
                          () => const LoginScreen());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.teal.shade600,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30)),
                    ),
                    child: const Text('Go to Login',
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
          data['message'] ?? 'Reset failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error', 'Connection error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              Get.back();
            }
          },
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ✅ Step Indicator
            Row(
              children: List.generate(3, (index) {
                final step       = index + 1;
                final isActive   = step == _currentStep;
                final isComplete = step < _currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isComplete || isActive
                              ? Colors.teal.shade600
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(Icons.check,
                                  color: Colors.white,
                                  size: 16)
                              : Text('$step',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors
                                            .grey.shade600,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 13,
                                  )),
                        ),
                      ),
                      if (index < 2)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isComplete
                                ? Colors.teal.shade600
                                : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // ✅ Step 1 — Enter Contact
            if (_currentStep == 1) ...[
              const Text(
                'Reset your password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your email or phone number to receive an OTP code.',
                style: TextStyle(
                    color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _contactController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email or Phone Number',
                  labelStyle: const TextStyle(
                      color: Colors.black54),
                  prefixIcon: Icon(
                      Icons.contact_mail_outlined,
                      color: Colors.teal.shade600),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.black26)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.teal.shade600)),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text(
                          'Send OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],

            // ✅ Step 2 — Enter OTP
            if (_currentStep == 2) ...[
              const Text(
                'Enter OTP Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _contactController.text.contains('@')
                    ? 'OTP sent to your email: ${_contactController.text}'
                    : 'OTP sent via SMS to: +975${_contactController.text}',
                style: const TextStyle(
                    color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade300,
                      letterSpacing: 8),
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.teal.shade600,
                        width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: _sendOtp,
                  child: Text('Resend OTP',
                      style: TextStyle(
                          color: Colors.teal.shade600)),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],

            // ✅ Step 3 — New Password
            if (_currentStep == 3) ...[
              const Text(
                'Set New Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your new password below.',
                style: TextStyle(
                    color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // New Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(
                      color: Colors.black54),
                  prefixIcon: Icon(Icons.lock_outline,
                      color: Colors.teal.shade600),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.black26)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.teal.shade600)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() =>
                        _obscurePassword =
                            !_obscurePassword),
                  ),
                ),
              ),

              // ✅ Password Strength
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildPasswordStrength(
                    _passwordController.text),
              ],

              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: _confirmPassController,
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
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.teal.shade600)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() =>
                        _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // ✅ Disable button until password is strong enough
                  onPressed: _isLoading
                      ? null
                      : _getStrengthLevel(_passwordController.text) < 4
                          ? null
                          : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _getStrengthLevel(_passwordController.text) < 4
                            ? Colors.grey.shade400  // ✅ Grey when disabled
                            : Colors.teal.shade600, // ✅ Teal when enabled),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text(
                          'Reset Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}