import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../controllers/auth_controller.dart';
import 'admin_home_screen.dart';

const kAdminColor = Color(0xFF00897B);

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() =>
      _AdminProfileScreenState();
}

class _AdminProfileScreenState
    extends State<AdminProfileScreen> {
  final _authController =
      Get.find<AuthController>();

  bool _isLoadingAvatar = false;
  String _avatarBase64  = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs =
        await SharedPreferences.getInstance();
    setState(() {
      _avatarBase64 =
          prefs.getString('admin_avatar') ?? '';
    });
  }

  Future<String> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // ✅ View full image
  void _viewImage() {
    if (_avatarBase64.isEmpty) {
      _pickAvatar();
      return;
    }
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // ✅ Full image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                base64Decode(_avatarBase64),
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),

            // ✅ Close button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black
                        .withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // ✅ Change photo button
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  Get.back();
                  _pickAvatar();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8),
                  decoration: BoxDecoration(
                    color: kAdminColor,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt,
                          color: Colors.white,
                          size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Change Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Pick avatar
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 8),
              child: const Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),

            // Gallery
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      kAdminColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                    Icons.photo_library_outlined,
                    color: kAdminColor),
              ),
              title:
                  const Text('Choose from Gallery'),
              onTap: () async {
                Get.back();
                final picked =
                    await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 400,
                  imageQuality: 70,
                );
                if (picked != null) {
                  final bytes =
                      await picked.readAsBytes();
                  await _uploadAvatar(
                      base64Encode(bytes));
                }
              },
            ),

            // Camera
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.blue.shade600),
              ),
              title: const Text('Take a Photo'),
              onTap: () async {
                Get.back();
                final picked =
                    await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 400,
                  imageQuality: 70,
                );
                if (picked != null) {
                  final bytes =
                      await picked.readAsBytes();
                  await _uploadAvatar(
                      base64Encode(bytes));
                }
              },
            ),

            // Remove
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline,
                    color: Colors.red.shade600),
              ),
              title: const Text('Remove Photo'),
              onTap: () async {
                Get.back();
                await _uploadAvatar('');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAvatar(
      String base64Str) async {
    setState(() => _isLoadingAvatar = true);
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(
            '${Constants.baseUrl}/admin/profile/avatar'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'avatar': base64Str}),
      );

      if (response.statusCode == 200) {
        final prefs =
            await SharedPreferences.getInstance();
        await prefs.setString(
            'admin_avatar', base64Str);
        setState(
            () => _avatarBase64 = base64Str);
        Get.snackbar('Updated',
            'Profile photo updated!',
            backgroundColor: kAdminColor,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Error: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoadingAvatar = false);
  }

  // ✅ Open Edit Password bottom sheet
  void _openEditPassword() {
    final currentPassCtrl =
        TextEditingController();
    final newPassCtrl     =
        TextEditingController();
    final confirmPassCtrl =
        TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew     = true;
    bool obscureConfirm = true;
    bool isLoading      = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setStateSheet) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context)
                      .viewInsets
                      .bottom +
                  20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  // Header
                  Row(
                    children: [
                      const Icon(
                          Icons.lock_outline,
                          color: kAdminColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Edit Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon:
                            const Icon(Icons.close),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),

                  const Divider(),
                  const SizedBox(height: 8),

                  // Current Password
                  TextField(
                    controller: currentPassCtrl,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: const TextStyle(
                          color: Colors.black54),
                      prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: kAdminColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black45,
                        ),
                        onPressed: () =>
                            setStateSheet(() =>
                                obscureCurrent =
                                    !obscureCurrent),
                      ),
                      focusedBorder:
                          const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                      enabledBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade300)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // New Password
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(
                          color: Colors.black54),
                      prefixIcon: const Icon(
                          Icons.lock_reset_outlined,
                          color: kAdminColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black45,
                        ),
                        onPressed: () =>
                            setStateSheet(() =>
                                obscureNew =
                                    !obscureNew),
                      ),
                      focusedBorder:
                          const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                      enabledBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade300)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Confirm Password
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(
                          color: Colors.black54),
                      prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: kAdminColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black45,
                        ),
                        onPressed: () =>
                            setStateSheet(() =>
                                obscureConfirm =
                                    !obscureConfirm),
                      ),
                      focusedBorder:
                          const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                      enabledBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade300)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (currentPassCtrl
                                      .text.isEmpty ||
                                  newPassCtrl
                                      .text.isEmpty ||
                                  confirmPassCtrl
                                      .text.isEmpty) {
                                Get.snackbar(
                                    'Error',
                                    'Fill all fields!',
                                    backgroundColor:
                                        Colors.orange,
                                    colorText:
                                        Colors.white,
                                    snackPosition:
                                        SnackPosition
                                            .BOTTOM);
                                return;
                              }
                              if (newPassCtrl.text !=
                                  confirmPassCtrl
                                      .text) {
                                Get.snackbar(
                                    'Error',
                                    'Passwords do not match!',
                                    backgroundColor:
                                        Colors.red,
                                    colorText:
                                        Colors.white,
                                    snackPosition:
                                        SnackPosition
                                            .BOTTOM);
                                return;
                              }
                              setStateSheet(() =>
                                  isLoading = true);
                              try {
                                final token =
                                    await _getToken();
                                final res =
                                    await http.put(
                                  Uri.parse(
                                      '${Constants.baseUrl}/admin/profile/password'),
                                  headers: {
                                    'Content-Type':
                                        'application/json',
                                    'Accept':
                                        'application/json',
                                    'Authorization':
                                        'Bearer $token',
                                  },
                                  body: jsonEncode({
                                    'current_password':
                                        currentPassCtrl
                                            .text,
                                    'new_password':
                                        newPassCtrl
                                            .text,
                                    'new_password_confirmation':
                                        confirmPassCtrl
                                            .text,
                                  }),
                                );
                                setStateSheet(() =>
                                    isLoading = false);
                                final data =
                                    jsonDecode(
                                        res.body);
                                if (res.statusCode ==
                                    200) {
                                  Get.back();
                                  Get.snackbar(
                                      'Success',
                                      'Password updated!',
                                      backgroundColor:
                                          kAdminColor,
                                      colorText:
                                          Colors.white,
                                      snackPosition:
                                          SnackPosition
                                              .BOTTOM);
                                } else {
                                  Get.snackbar(
                                      'Error',
                                      data['message'] ??
                                          'Failed!',
                                      backgroundColor:
                                          Colors.red,
                                      colorText:
                                          Colors.white,
                                      snackPosition:
                                          SnackPosition
                                              .BOTTOM);
                                }
                              } catch (e) {
                                setStateSheet(() =>
                                    isLoading = false);
                                Get.snackbar(
                                    'Error',
                                    'Error: $e',
                                    backgroundColor:
                                        Colors.red,
                                    colorText:
                                        Colors.white,
                                    snackPosition:
                                        SnackPosition
                                            .BOTTOM);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAdminColor,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    8)),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text(
                              'Update Password',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  // ✅ Open Edit Email bottom sheet
  void _openEditEmail() {
    final emailCtrl = TextEditingController(
        text: _authController.userEmail.value);
    final passCtrl  = TextEditingController();
    bool obscurePass = true;
    bool isLoading   = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setStateSheet) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context)
                      .viewInsets
                      .bottom +
                  20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  // Header
                  Row(
                    children: [
                      const Icon(
                          Icons.email_outlined,
                          color: kAdminColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Edit Email',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon:
                            const Icon(Icons.close),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),

                  const Divider(),
                  const SizedBox(height: 8),

                  // New Email
                  TextField(
                    controller: emailCtrl,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'New Email',
                      labelStyle: const TextStyle(
                          color: Colors.black54),
                      prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: kAdminColor),
                      focusedBorder:
                          const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                      enabledBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade300)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Password confirm
                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText:
                          'Confirm with Password',
                      labelStyle: const TextStyle(
                          color: Colors.black54),
                      prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: kAdminColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black45,
                        ),
                        onPressed: () =>
                            setStateSheet(() =>
                                obscurePass =
                                    !obscurePass),
                      ),
                      focusedBorder:
                          const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: kAdminColor)),
                      enabledBorder:
                          UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade300)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (emailCtrl
                                      .text.isEmpty ||
                                  passCtrl
                                      .text.isEmpty) {
                                Get.snackbar(
                                    'Error',
                                    'Fill all fields!',
                                    backgroundColor:
                                        Colors.orange,
                                    colorText:
                                        Colors.white,
                                    snackPosition:
                                        SnackPosition
                                            .BOTTOM);
                                return;
                              }
                              setStateSheet(() =>
                                  isLoading = true);
                              try {
                                final token =
                                    await _getToken();
                                final res =
                                    await http.put(
                                  Uri.parse(
                                      '${Constants.baseUrl}/admin/profile/email'),
                                  headers: {
                                    'Content-Type':
                                        'application/json',
                                    'Accept':
                                        'application/json',
                                    'Authorization':
                                        'Bearer $token',
                                  },
                                  body: jsonEncode({
                                    'email': emailCtrl
                                        .text
                                        .trim(),
                                    'password':
                                        passCtrl.text,
                                  }),
                                );
                                setStateSheet(() =>
                                    isLoading = false);
                                final data =
                                    jsonDecode(
                                        res.body);
                                if (res.statusCode ==
                                    200) {
                                  final prefs =
                                      await SharedPreferences
                                          .getInstance();
                                  await prefs.setString(
                                      'user_email',
                                      emailCtrl.text
                                          .trim());
                                  _authController
                                          .userEmail
                                          .value =
                                      emailCtrl.text
                                          .trim();
                                  Get.back();
                                  Get.snackbar(
                                      'Success',
                                      'Email updated!',
                                      backgroundColor:
                                          kAdminColor,
                                      colorText:
                                          Colors.white,
                                      snackPosition:
                                          SnackPosition
                                              .BOTTOM);
                                } else {
                                  Get.snackbar(
                                      'Error',
                                      data['message'] ??
                                          'Failed!',
                                      backgroundColor:
                                          Colors.red,
                                      colorText:
                                          Colors.white,
                                      snackPosition:
                                          SnackPosition
                                              .BOTTOM);
                                }
                              } catch (e) {
                                setStateSheet(() =>
                                    isLoading = false);
                                Get.snackbar(
                                    'Error',
                                    'Error: $e',
                                    backgroundColor:
                                        Colors.red,
                                    colorText:
                                        Colors.white,
                                    snackPosition:
                                        SnackPosition
                                            .BOTTOM);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAdminColor,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    8)),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text(
                              'Update Email',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminColor,
      appBar: AppBar(
        backgroundColor: kAdminColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [

          // ── Top Green Section ──
          Container(
            width: double.infinity,
            color: kAdminColor,
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 30),
            child: Column(
              children: [

                // ✅ Avatar - tap to view, long press to change
                GestureDetector(
                  onLongPress: _pickAvatar,
                  onTap: _viewImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white
                            .withOpacity(0.3),
                        backgroundImage:
                            _avatarBase64.isNotEmpty
                                ? MemoryImage(
                                    base64Decode(
                                        _avatarBase64))
                                : null,
                        child: _avatarBase64.isEmpty
                            ? const Icon(
                                Icons
                                    .admin_panel_settings,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding:
                              const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: kAdminColor,
                                width: 2),
                          ),
                          child: _isLoadingAvatar
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(
                                    color: kAdminColor,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: kAdminColor,
                                  size: 14,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ✅ Hint text
                Text(
                  _avatarBase64.isNotEmpty
                      ? 'Tap to view • Long press to change'
                      : 'Tap to add photo',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 10),

                // Name
                Text(
                  _authController.userName.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                // Email
                Obx(() => Text(
                  _authController.userEmail.value,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        Colors.white.withOpacity(0.8),
                  ),
                )),

                const SizedBox(height: 8),

                // Admin badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withOpacity(0.2),
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white
                            .withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Administrator',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── White Content Section ──
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [

                    const SizedBox(height: 10),

                    // ✅ Edit Password Button
                    _actionButton(
                      icon: Icons.lock_outline,
                      title: 'Edit Password',
                      subtitle:
                          'Change your account password',
                      onTap: _openEditPassword,
                    ),

                    const SizedBox(height: 12),

                    // ✅ Edit Email Button
                    _actionButton(
                      icon: Icons.email_outlined,
                      title: 'Edit Email',
                      subtitle:
                          'Update your email address',
                      onTap: _openEditEmail,
                    ),

                    const Spacer(),

                    // ✅ Bottom Green Container
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20),
                      decoration: BoxDecoration(
                        color: kAdminColor,
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceEvenly,
                        children: [

                          // ✅ Home Icon
                          GestureDetector(
                            onTap: () => Get.offAll(
                                () => const AdminHomeScreen()),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .all(12),
                                  decoration:
                                      BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(
                                            0.2),
                                    shape:
                                        BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.home_outlined,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(
                                    height: 4),
                                const Text(
                                  'Home',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Divider
                          Container(
                            height: 50,
                            width: 1,
                            color: Colors.white
                                .withOpacity(0.3),
                          ),

                          // ✅ Logout Icon
                          GestureDetector(
                            onTap: () =>
                                _authController
                                    .logout(),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .all(12),
                                  decoration:
                                      BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(
                                            0.2),
                                    shape:
                                        BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons
                                        .power_settings_new,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(
                                    height: 4),
                                const Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Action button widget
  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kAdminColor.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: kAdminColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}