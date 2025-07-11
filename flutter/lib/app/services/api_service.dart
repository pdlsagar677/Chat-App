import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  // Get base URL dynamically based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5001'; // Web runs on localhost
    } else if (Platform.isAndroid) {
      // Use this IP for Android emulator
      return 'http://10.0.2.2:5001';
      // For real devices, replace with your machine's local network IP, e.g.:
      // return 'http://192.168.56.1:5001';
    } else if (Platform.isIOS) {
      // For iOS simulator or device, use your local network IP
      return 'http://172.16.3.39:5001';
    } else {
      // Fallback to localhost for other platforms
      return 'http://localhost:5001';
    }
  }

  // Existing login method
  static Future<Map<String, dynamic>> loginUser(
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/api/auth/login');

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Login failed');
    }
  }
}
