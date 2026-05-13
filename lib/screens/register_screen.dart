import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../controllers/auth_controller.dart';
import '../utils/constants.dart';
import 'rate_us_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'feedback_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authController = Get.find<AuthController>();

  int _currentStep = 1;

  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController             = TextEditingController();
  final _scaffoldKey               = GlobalKey<ScaffoldState>();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading       = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ✅ Bhutan phone validation — BMobile: 17/77, TCell: 16/8
  bool _isValidBhutanPhone(String phone) {
    if (phone.length != 8) return false;
    final regex = RegExp(r'^(17|77|16|8)\d{6,7}$');
    return regex.hasMatch(phone);
  }

  String _phoneHelperText(String phone) {
    if (phone.isEmpty) return '';
    if (!RegExp(r'^\d+$').hasMatch(phone)) return 'Numbers only';
    if (phone.length < 8) return 'Must be 8 digits';
    if (!_isValidBhutanPhone(phone)) return 'Invalid Bhutan number (BMobile: 17/77, TCell: 16/8)';
    return '✅ Valid Bhutan number';
  }

  Color _phoneHelperColor(String phone) {
    if (phone.isEmpty) return Colors.black45;
    if (_isValidBhutanPhone(phone)) return Colors.green;
    return Colors.red;
  }

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
                  color: index < level ? color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _checkItem('At least 8 characters', checks['min8']!),
        _checkItem('Uppercase letter (A-Z)', checks['uppercase']!),
        _checkItem('Lowercase letter (a-z)', checks['lowercase']!),
        _checkItem('Number (0-9)', checks['number']!),
      ],
    );
  }

  Widget _checkItem(String text, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle : Icons.cancel, size: 14,
              color: passed ? Colors.green : Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11,
              color: passed ? Colors.green : Colors.grey.shade500)),
        ],
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill all required fields!',
          backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // ✅ Validate phone
    if (!_isValidBhutanPhone(_phoneController.text.trim())) {
      Get.snackbar('Invalid Phone',
          'Enter a valid Bhutan number (BMobile: 17/77, TCell: 16/8)',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4));
      return;
    }

    final email     = _emailController.text.trim();
    final jnecRegex = RegExp(r'^[a-zA-Z0-9._-]+\.jnec@rub\.edu\.bt$');
    if (!jnecRegex.hasMatch(email)) {
      Get.snackbar('Invalid Email', 'Must be in format: name.jnec@rub.edu.bt',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      Get.snackbar('Error', 'Passwords do not match!',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/send-registration-otp'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'name': _nameController.text}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        Get.snackbar('OTP Sent!', 'Please check your JNEC email inbox.',
            backgroundColor: Colors.teal.shade600, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
        setState(() => _currentStep = 2);
      } else {
        Get.snackbar('Error', data['message'] ?? 'Failed to send OTP',
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndRegister() async {
    if (_otpController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter the OTP code!',
          backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final verifyResponse = await http.post(
        Uri.parse('${Constants.baseUrl}/verify-registration-otp'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim(), 'code': _otpController.text.trim()}),
      );
      final verifyData = jsonDecode(verifyResponse.body);
      if (verifyResponse.statusCode != 200) {
        Get.snackbar('Error', verifyData['message'] ?? 'Invalid OTP!',
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        setState(() => _isLoading = false);
        return;
      }
      await _authController.register(
        name:     _nameController.text,
        email:    _emailController.text.trim(),
        phone:    _phoneController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              color: const Color(0xFF00897B),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2)),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  Text('JNEC Eco-Trade System',
                      style: TextStyle(color: Colors.green.shade100, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.star_outline, color: Colors.black54), title: const Text('Rate Us'),
                onTap: () { Get.back(); Get.to(() => const RateUsScreen()); }),
            ListTile(leading: const Icon(Icons.phone_outlined, color: Colors.black54), title: const Text('Contact Us'),
                onTap: () { Get.back(); Get.to(() => const ContactUsScreen()); }),
            ListTile(leading: const Icon(Icons.info_outline, color: Colors.black54), title: const Text('About Us'),
                onTap: () { Get.back(); Get.to(() => const AboutUsScreen()); }),
            ListTile(leading: const Icon(Icons.mail_outline, color: Colors.black54), title: const Text('Feedback'),
                onTap: () { Get.back(); Get.to(() => const FeedbackScreen()); }),
            const Spacer(),
            Padding(padding: const EdgeInsets.all(16),
                child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: const Icon(Icons.menu, size: 28, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              const Center(
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Color(0xFFE0E0E0),
                  child: Icon(Icons.person, size: 50, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text('Sign up', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(height: 12),

              // ── Step Indicator ──
              Row(
                children: List.generate(2, (index) {
                  final step     = index + 1;
                  final isActive = step == _currentStep;
                  final isDone   = step < _currentStep;
                  return Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: isDone || isActive ? Colors.teal.shade600 : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : Text('$step', style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        if (index < 1)
                          Expanded(child: Container(height: 2,
                              color: isDone ? Colors.teal.shade600 : Colors.grey.shade300)),
                      ],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // ── STEP 1 ──
              if (_currentStep == 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Only JNEC students & staff can register. An OTP will be sent to verify your email.',
                        style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                      )),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Full Name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *', labelStyle: TextStyle(color: Colors.black54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                  ),
                ),

                const SizedBox(height: 16),

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'name.jnec@rub.edu.bt',
                    hintStyle: TextStyle(color: Colors.black26, fontSize: 12),
                    helperText: 'Format: name.jnec@rub.edu.bt or std_id.jnec@rub.edu.bt',
                    helperStyle: TextStyle(color: Colors.teal, fontSize: 11),
                    labelStyle: TextStyle(color: Colors.black54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ Phone — REQUIRED with Bhutan validation
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Contact Number *',
                    labelStyle: const TextStyle(color: Colors.black54),
                    hintText: 'e.g. 77123456 or 17123456',
                    hintStyle: const TextStyle(color: Colors.black26, fontSize: 12),
                    counterText: '',
                    helperText: _phoneController.text.isEmpty
                        ? 'BMobile: 17/77, TCell: 16/8'
                        : _phoneHelperText(_phoneController.text),
                    helperStyle: TextStyle(
                        color: _phoneHelperColor(_phoneController.text), fontSize: 11),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: _phoneController.text.isNotEmpty && !_isValidBhutanPhone(_phoneController.text)
                                ? Colors.red
                                : Colors.black26)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: _phoneController.text.isNotEmpty && !_isValidBhutanPhone(_phoneController.text)
                                ? Colors.red
                                : Colors.teal)),
                  ),
                ),

                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Password *', labelStyle: const TextStyle(color: Colors.black54),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.black45),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildPasswordStrength(_passwordController.text),
                ],

                const SizedBox(height: 16),

                // Confirm Password
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *', labelStyle: const TextStyle(color: Colors.black54),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.black45),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _getStrengthLevel(_passwordController.text) < 4
                            ? null
                            : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStrengthLevel(_passwordController.text) < 4
                          ? Colors.grey.shade400
                          : Colors.teal.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send OTP to Email',
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],

              // ── STEP 2 ──
              if (_currentStep == 2) ...[
                const Text('Verify Your Email',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                    children: [
                      const TextSpan(text: 'OTP sent to '),
                      TextSpan(text: _emailController.text,
                          style: TextStyle(color: Colors.teal.shade600, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 10),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 8),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.shade600, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: TextButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    child: Text('Resend OTP', style: TextStyle(color: Colors.teal.shade600)))),
                Center(child: TextButton(
                    onPressed: () => setState(() => _currentStep = 1),
                    child: Text('Change Email', style: TextStyle(color: Colors.grey.shade600)))),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _getStrengthLevel(_passwordController.text) < 4
                            ? null
                            : _verifyAndRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStrengthLevel(_passwordController.text) < 4
                          ? Colors.grey.shade400
                          : Colors.teal.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Verify & Create Account',
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(color: Colors.black54)),
                    GestureDetector(
                      onTap: () => Get.offAll(() => const LoginScreen()),
                      child: Text('Login', style: TextStyle(color: Colors.teal.shade600, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}