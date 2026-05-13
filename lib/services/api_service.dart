import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class ApiService {
  static Future<String> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/test'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        return 'Error: ${response.statusCode}';
      }
    } catch (e) {
      return 'Failed to connect: $e';
    }
  }
}