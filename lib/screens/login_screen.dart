import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../controllers/auth_controller.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'rate_us_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'feedback_screen.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authController = Get.find<AuthController>();

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _scaffoldKey        = GlobalKey<ScaffoldState>();

  bool _obscurePassword = true;
  bool _rememberMe      = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    try {
       // ✅ iOS uses clientId, Android uses serverClientId only
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '451160567687-4rmhro65d84675upeih8ah4ah69sl36d.apps.googleusercontent.com',
        clientId: Platform.isIOS
            ? '938854441807-r4l3rg838qkshq99h5bpvj656mr2udhs.apps.googleusercontent.com'
            : null,
      );

      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final email     = googleUser.email;
      final jnecRegex = RegExp(r'^[a-zA-Z0-9._-]+\.jnec@rub\.edu\.bt$');

      if (!jnecRegex.hasMatch(email)) {
        await googleSignIn.signOut();
        Get.snackbar(
          'Access Denied',
          'Only JNEC official email (stdid.jnec@rub.edu.bt) is accepted!',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      await _authController.googleLogin(
        name:  googleUser.displayName ?? '',
        email: email,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Google login failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Green Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              color: const Color(0xFF00897B),
              child: Column(
                children: [
                  // ✅ Drawer logo — contain, no cropping
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        width: 80,  // ✅ slightly larger than container to fill edges
                        height: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'JNEC Eco-Trade System',
                    style: TextStyle(
                      color: Colors.green.shade100,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.star_outline, color: Colors.black54),
              title: const Text('Rate Us'),
              onTap: () { Get.back(); Get.to(() => const RateUsScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined, color: Colors.black54),
              title: const Text('Contact Us'),
              onTap: () { Get.back(); Get.to(() => const ContactUsScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.black54),
              title: const Text('About Us'),
              onTap: () { Get.back(); Get.to(() => const AboutUsScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline, color: Colors.black54),
              title: const Text('Feedback'),
              onTap: () { Get.back(); Get.to(() => const FeedbackScreen()); },
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFE8F5E9),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Burger Menu ──
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: const Icon(Icons.menu, color: Colors.black87, size: 28),
                ),
              ),

              const SizedBox(height: 10),

              // ✅ Logo — plain image, no white box, sits on green background
              SizedBox(
                width: 130,
                height: 130,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 10),

              // ── Title ──
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              // ── Email ──
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email or Phone Number',
                  hintStyle: const TextStyle(color: Colors.black45),
                  helperText: 'Email must be official JNEC email (@rub.edu.bt)',
                  helperStyle: TextStyle(color: Colors.green.shade700, fontSize: 11),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green.shade700)),
                ),
              ),

              const SizedBox(height: 20),

              // ── Password ──
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.black45),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green.shade700)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black45,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Remember Me & Forgot Password ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: Colors.green.shade700,
                        onChanged: (val) => setState(() => _rememberMe = val!),
                      ),
                      const Text('Remember me', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Get.to(() => const ResetPasswordScreen()),
                    child: Text(
                      'Forget password?',
                      style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Login Button ──
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _authController.isLoading.value
                        ? null
                        : () => _authController.login(
                              emailOrPhone: _emailController.text.trim(),
                              password: _passwordController.text,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _authController.isLoading.value
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── OR divider ──
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.black38)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or login with',
                        style: TextStyle(color: Colors.black54)),
                  ),
                  Expanded(child: Divider(color: Colors.black38)),
                ],
              ),

              const SizedBox(height: 20),

              // ── Google Login ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _handleGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Login with Google',
                        style: TextStyle(color: Colors.black87, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign Up ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Get.to(() => const RegisterScreen()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Sign up',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
