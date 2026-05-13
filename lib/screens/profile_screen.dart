import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/auth_controller.dart';
import 'edit_profile_screen.dart';
import 'edit_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final _authController =
      Get.find<AuthController>();

  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  // ✅ Load from correct key
  Future<void> _loadProfileImage() async {
    final prefs =
        await SharedPreferences.getInstance();
    final imageBase64 =
        prefs.getString('user_avatar'); // ✅ Fixed
    if (imageBase64 != null &&
        imageBase64.isNotEmpty) {
      setState(() {
        _profileImageBytes =
            base64Decode(imageBase64);
      });
    }
  }

  // ✅ View full image dialog
  void _viewProfileImage() {
    if (_profileImageBytes == null) return;
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [

            // ✅ Full image
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(16),
              child: Image.memory(
                _profileImageBytes!,
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
                  padding:
                      const EdgeInsets.all(6),
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
                  _showImagePickerOptions();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade600,
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
                          fontWeight:
                              FontWeight.bold,
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

  // ✅ Show image picker options
  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // ✅ View - only if has image
              if (_profileImageBytes != null)
                ListTile(
                  leading: Container(
                    padding:
                        const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        Icons.image_outlined,
                        color:
                            Colors.teal.shade600),
                  ),
                  title:
                      const Text('View Photo'),
                  subtitle: const Text(
                      'View your profile photo'),
                  onTap: () {
                    Get.back();
                    _viewProfileImage();
                  },
                ),

              // ✅ Camera
              ListTile(
                leading: Container(
                  padding:
                      const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt,
                      color:
                          Colors.teal.shade600),
                ),
                title:
                    const Text('Take a Photo'),
                subtitle:
                    const Text('Use your camera'),
                onTap: () {
                  Get.back();
                  _pickImage(ImageSource.camera);
                },
              ),

              // ✅ Gallery
              ListTile(
                leading: Container(
                  padding:
                      const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      Icons.photo_library,
                      color:
                          Colors.teal.shade600),
                ),
                title: const Text(
                    'Choose from Gallery'),
                subtitle: const Text(
                    'Select from your photos'),
                onTap: () {
                  Get.back();
                  _pickImage(ImageSource.gallery);
                },
              ),

              // ✅ Remove - only if has image
              if (_profileImageBytes != null)
                ListTile(
                  leading: Container(
                    padding:
                        const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red),
                  ),
                  title:
                      const Text('Remove Photo'),
                  subtitle: const Text(
                      'Use default avatar'),
                  onTap: () async {
                    Get.back();
                    final prefs =
                        await SharedPreferences
                            .getInstance();
                    await prefs.remove(
                        'user_avatar'); // ✅ Fixed
                    setState(() =>
                        _profileImageBytes = null);
                    // ✅ Update auth controller
                    _authController
                        .userAvatar.value = '';
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Pick image
  Future<void> _pickImage(
      ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 400,
        imageQuality: 70,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Image = base64Encode(bytes);

        // ✅ Save with correct key
        final prefs =
            await SharedPreferences.getInstance();
        await prefs.setString(
            'user_avatar', base64Image); // ✅ Fixed

        setState(
            () => _profileImageBytes = bytes);

        // ✅ Update auth controller observable
        _authController.userAvatar.value =
            base64Image;

        Get.snackbar('Success',
            'Profile photo updated!',
            backgroundColor:
                Colors.teal.shade600,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error',
          'Error picking image: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
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
        title: const Text(
          'My Profile',
          style: TextStyle(
              fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // ── Profile Picture ──
            Center(
              child: Stack(
                children: [

                  // ✅ Tap to view if has image
                  GestureDetector(
                    onTap: () {
                      if (_profileImageBytes !=
                          null) {
                        _viewProfileImage();
                      } else {
                        _showImagePickerOptions();
                      }
                    },
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor:
                          Colors.grey.shade300,
                      backgroundImage:
                          _profileImageBytes != null
                              ? MemoryImage(
                                  _profileImageBytes!)
                              : null,
                      child:
                          _profileImageBytes == null
                              ? const Icon(
                                  Icons.person,
                                  size: 65,
                                  color: Colors.grey,
                                )
                              : null,
                    ),
                  ),

                  // ✅ Camera icon
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap:
                          _showImagePickerOptions,
                      child: Container(
                        padding:
                            const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              Colors.teal.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white,
                              width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Edit Buttons ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 40),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await Get.to(
                            () => EditProfileScreen(
                          name: _authController
                              .userName.value,
                          email: _authController
                              .userEmail.value,
                          phone: _authController
                              .userPhone.value,
                        ));
                        await _authController
                            .loadUserData();
                      },
                      style:
                          OutlinedButton.styleFrom(
                        side: BorderSide(
                            color:
                                Colors.teal.shade600),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  8),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 10),
                      ),
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          color:
                              Colors.teal.shade600,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.to(() =>
                          const EditPasswordScreen()),
                      style:
                          OutlinedButton.styleFrom(
                        side: BorderSide(
                            color:
                                Colors.teal.shade600),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  8),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 10),
                      ),
                      child: Text(
                        'Edit Password',
                        style: TextStyle(
                          color:
                              Colors.teal.shade600,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Personal Info ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Info',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Obx(() => Column(
                    children: [
                      _infoRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: _authController
                            .userName.value,
                      ),
                      _divider(),
                      _infoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _authController
                            .userEmail.value,
                      ),
                      _divider(),
                      _infoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        value: _authController
                                .userPhone
                                .value
                                .isEmpty
                            ? 'Not set'
                            : _authController
                                .userPhone.value,
                      ),
                    ],
                  )),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),

      // ✅ Bottom Nav
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        backgroundColor: Colors.teal.shade600,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        onTap: (index) {
          if (index == 0) {
            Get.back();
          } else if (index == 1) {
            _authController.logout();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.power_settings_new),
            label: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 20,
              color: Colors.teal.shade600),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
        color: Colors.grey.shade200, height: 1);
  }
}