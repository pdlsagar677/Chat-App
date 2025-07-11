import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Automatically selects the correct base URL based on platform.
String getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:5001';
  } else {
    // For mobile:
    // - Use 10.0.2.2 for Android Emulator
    // - Use your computer's IP (e.g., 192.168.x.x) for real device
    return 'http://172.16.3.39:5001'; // 🔁 Replace this with your actual local IP
  }
}

class AuthService {
  final String baseUrl = getBaseUrl();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'body': {'message': 'Login failed: $e'},
      };
    }
  }
}
