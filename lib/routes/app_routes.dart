import 'package:get/get.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/main_nav_screen.dart';
import '../screens/admin/admin_home_screen.dart';

class AppRoutes {
  // ✅ Route names
  static const splash   = '/splash';
  static const login    = '/login';
  static const register = '/register';
  static const home     = '/home';
  static const adminHome  = '/admin-home'; 

  // ✅ Route pages
  static final routes = [
    GetPage(name: splash,   page: () => const SplashScreen()),
    GetPage(name: login,    page: () => const LoginScreen()),
    GetPage(name: register, page: () => const RegisterScreen()),
    // ✅ Home now launches MainNavScreen — hosts all 5 tabs in a real
    // sliding PageView (Home, My Listings, Post, Offers, Profile)
    GetPage(name: home,     page: () => const MainNavScreen()),
    GetPage(name: adminHome, page: () => const AdminHomeScreen()),
  ];
}