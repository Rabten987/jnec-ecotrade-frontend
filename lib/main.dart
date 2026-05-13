import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/splash_screen.dart';
import 'controllers/auth_controller.dart';
import 'routes/app_routes.dart';
import 'controllers/saved_controller.dart';
import 'controllers/cart_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ReDruk - JNEC Eco-trade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal),
        useMaterial3: true,

        // ✅ Fix Cancel button in all dialogs
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black87,
          ),
        ),
      ),

      // ✅ Register controllers globally
      initialBinding: BindingsBuilder(() {
        Get.put(AuthController(),
            permanent: true);
        Get.put(SavedController(),
            permanent: true);
        Get.put(CartController(),
            permanent: true);
      }),

      // ✅ GetX routes
      getPages: AppRoutes.routes,
      home: const SplashScreen(),
    );
  }
}