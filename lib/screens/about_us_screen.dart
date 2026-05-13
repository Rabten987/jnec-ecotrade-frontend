import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: const Text('About Us'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(), // ✅ GetX
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.teal.shade600, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Welcome to the JNEC Online Eco-Trade System — a platform designed to promote sustainability and responsible consumption within our college community. This system enables students and staff to buy, sell, or donate second-hand items such as textbooks, electronics, furniture, and other essentials.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Our goal is to:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            _bulletPoint(
                'Encourage reuse of usable items to minimize waste.'),
            _bulletPoint(
                'Support affordability for students by offering second-hand goods at lower prices.'),
            _bulletPoint(
                'Create a connected campus where resources can be shared efficiently and ethically.'),

            const SizedBox(height: 16),

            const Text(
              'Key Features:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            _bulletPoint(
                'Secure login and registration for buyers and sellers.'),
            _bulletPoint('Easy-to-use item listing and browsing.'),
            _bulletPoint(
                'In-app feedback and rating to ensure trust and transparency.'),
            _bulletPoint(
                'Admin dashboard for user management and report generation.'),

            const SizedBox(height: 16),

            const Text(
              'This initiative aligns with JNEC\'s commitment to environmental awareness and community support. Whether you\'re decluttering your room or looking for affordable items, the Eco-Trade System is your sustainable solution.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style:
                  TextStyle(fontSize: 14, color: Colors.black87)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}