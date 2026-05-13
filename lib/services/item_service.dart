import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ItemService {

  static Future<Map<String, dynamic>> postItem({
    required String itemName,
    required String condition,
    required String category,
    required double price,
    required String location,
    required String contactPreference,
    String? image,
  }) async {
    try {
      // ✅ Get token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // ✅ Debug - print token to check
      print('Token: $token');

      if (token.isEmpty) {
        return {
          'success': false,
          'message': 'You are not logged in. Please login first.'
        };
      }

      final response = await http.post(
        Uri.parse(Constants.productsUrl),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',  // ✅ Token sent here
        },
        body: jsonEncode({
          'item_name':          itemName,
          'condition':          condition,
          'category':           category,
          'price':              price,
          'location':           location,
          'contact_preference': contactPreference,
          'image':              image,
        }),
      );

      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to post item'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getItems({
    String category = 'All',
    String search = '',
  }) async {
    try {
      final url =
          '${Constants.productsUrl}?category=$category&search=$search';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load items'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}