import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../routes/app_routes.dart';
import '../screens/profile_screen.dart';

class AuthController extends GetxController {

  // ✅ Observable variables
  final isLoading  = false.obs;
  final userName   = ''.obs;
  final userEmail  = ''.obs;
  final userPhone  = ''.obs;
  final userRole   = ''.obs;
  final token      = ''.obs;
  final userAvatar = ''.obs;

  // ✅ Track if this is a Google login with no phone
  final needsContactPrompt = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
  }

  // ✅ Load saved user data
  Future<void> loadUserData() async {
    final prefs      = await SharedPreferences.getInstance();
    userName.value   = prefs.getString('user_name')   ?? '';
    userEmail.value  = prefs.getString('user_email')  ?? '';
    userPhone.value  = prefs.getString('user_phone')  ?? '';
    userRole.value   = prefs.getString('user_role')   ?? '';
    token.value      = prefs.getString('token')       ?? '';
    userAvatar.value = prefs.getString('user_avatar') ?? '';
  }

  // ✅ Update profile image
  Future<void> updateAvatar(String base64Image) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', base64Image);
      userAvatar.value = base64Image;

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/profile/avatar'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer ${token.value}',
        },
        body: jsonEncode({'avatar': base64Image}),
      );

      if (response.statusCode == 200) {
        Get.snackbar('Success', 'Profile photo updated!',
            backgroundColor: Colors.teal.shade600,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint('Avatar error: $e');
    }
  }

  // ✅ Show contact prompt — called from HomeScreen after Google login
  void showContactPromptIfNeeded() {
    if (!needsContactPrompt.value) return;
    needsContactPrompt.value = false;

    // ✅ Delay 2 seconds so home screen fully loads first
    Future.delayed(const Duration(seconds: 2), () {
      Get.snackbar(
        '📱 Complete Your Profile',
        'Please add your contact number so buyers can reach you.',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        icon: const Icon(Icons.phone_outlined, color: Colors.white),
        mainButton: TextButton(
          onPressed: () {
            Get.back(); // close snackbar
            // ✅ Navigate to profile screen directly
            Get.to(() => const ProfileScreen());
          },
          child: const Text(
            'Go to Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    });
  }

  // ✅ Login
  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    if (emailOrPhone.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'Please enter email/phone and password!',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final isEmail = emailOrPhone.contains('@');
    if (isEmail) {
      final isAdmin = emailOrPhone == 'admin@redruk.com';
      final isJnec  = RegExp(r'^[a-zA-Z0-9._-]+\.jnec@rub\.edu\.bt$')
          .hasMatch(emailOrPhone);

      if (!isAdmin && !isJnec) {
        Get.snackbar(
          'Invalid Email',
          'Only JNEC official email or admin email is accepted!',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }
    }

    isLoading.value = true;

    try {
      final response = await http.post(
        Uri.parse(Constants.loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({
          'email':    emailOrPhone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token',      data['token']);
        await prefs.setString('user_name',  data['user']['name']  ?? '');
        await prefs.setString('user_email', data['user']['email'] ?? '');
        await prefs.setString('user_role',  data['user']['role']  ?? 'user');
        await prefs.setString('user_phone', data['user']['phone'] ?? '');

        await loadUserData();

        final role = data['user']['role'] ?? 'user';
        if (role == 'admin') {
          Get.offAllNamed(AppRoutes.adminHome);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
      } else {
        Get.snackbar('Login Failed', data['message'] ?? 'Invalid credentials',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ Google Login
  Future<void> googleLogin({
    required String name,
    required String email,
  }) async {
    isLoading.value = true;
    try {
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/google-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({'name': name, 'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token',      data['token']);
        await prefs.setString('user_name',  data['user']['name']  ?? '');
        await prefs.setString('user_email', data['user']['email'] ?? '');
        await prefs.setString('user_role',  data['user']['role']  ?? 'user');
        await prefs.setString('user_phone', data['user']['phone'] ?? '');

        await loadUserData();

        // ✅ Check if phone is empty after Google login
        //    Google accounts have no phone — prompt user to fill it
        final phone = data['user']['phone'] ?? '';
        if (phone.isEmpty) {
          needsContactPrompt.value = true;
        }

        Get.offAllNamed(AppRoutes.home);
      } else {
        Get.snackbar('Login Failed', data['message'] ?? 'Google login failed',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ Register
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final response = await http.post(
        Uri.parse(Constants.registerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode({
          'name':                  name,
          'email':                 email,
          'phone':                 phone,
          'password':              password,
          'password_confirmation': password,
          'role':                  'user',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final loginResponse = await http.post(
          Uri.parse(Constants.loginUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
          },
          body: jsonEncode({'email': email, 'password': password}),
        );

        final loginData = jsonDecode(loginResponse.body);

        if (loginResponse.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token',      loginData['token']);
          await prefs.setString('user_name',  loginData['user']['name']  ?? '');
          await prefs.setString('user_email', loginData['user']['email'] ?? '');
          await prefs.setString('user_role',  loginData['user']['role']  ?? 'user');
          await prefs.setString('user_phone', loginData['user']['phone'] ?? '');

          await loadUserData();

          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 60),
                  const SizedBox(height: 16),
                  const Text('Account Created!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Your account has been created successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 14)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.offAllNamed(AppRoutes.home);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Go to Home',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            barrierDismissible: false,
          );
        } else {
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 60),
                  const SizedBox(height: 16),
                  const Text('Account Created!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Please login with your credentials.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 14)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.offAllNamed(AppRoutes.login);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Go to Login',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            barrierDismissible: false,
          );
        }
      } else {
        Get.snackbar('Error', data['message'] ?? 'Registration failed',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection error: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ Logout
  Future<void> logout() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      token.value     = '';
      userName.value  = '';
      userEmail.value = '';
      userRole.value  = '';
      userPhone.value = '';
      userAvatar.value = '';
      needsContactPrompt.value = false;

      Get.offAllNamed(AppRoutes.login);
    }
  }
}