import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:chat_app/app/screens/home/home_screen.dart';
import 'package:chat_app/app/utils/safe_navigator.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';

class LoginController extends GetxController {
  final isLoading = false.obs;
  final storage = GetStorage();

  /// Returns true on success, false on failure
  Future<bool> loginUser(String email, String password) async {
    // Dynamic base URL based on platform
    final String baseUrl =
        kIsWeb
            ? "http://172.16.3.128:5001"
            : "http://172.16.3.128:5001"; // use real IP for all devices

    final Uri url = Uri.parse("$baseUrl/api/auth/login");
    try {
      isLoading.value = true;

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Raw response body: ${response.body}');

      if (response.statusCode == 200 &&
          (response.headers['content-type']?.contains('application/json') ??
              false)) {
        if (response.body.isEmpty) {
          Get.snackbar(
            "Error",
            "Empty response received from server.",
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
          );
          return false;
        }

        final data = jsonDecode(response.body);

        // Save token if present
        final token = data['token'];
        if (token != null) {
          await storage.write('auth_token', token);
        }

        // Save user details
        await storage.write('user_id', data['_id']);
        await storage.write('user_fullName', data['fullName']);
        await storage.write('user_email', data['email']);
        await storage.write(
          'user_profilePic',
          data['profilePic']?.toString().isNotEmpty == true
              ? data['profilePic']
              : null, // null-safe fallback
        );

        // Delay snackbar and navigation to avoid _debugLocked error
        Future.delayed(Duration.zero, () {
          Get.snackbar(
            "Welcome!",
            "Login successful",
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
          );

          SafeNavigator.to(() => HomeScreen());
        });

        return true;
      } else {
        final errorMessage =
            response.body.isNotEmpty
                ? (jsonDecode(response.body)['message'] ??
                    'Invalid credentials or server error')
                : 'Login failed. Please try again.';

        Get.snackbar(
          "Login Failed",
          errorMessage,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        return false;
      }
    } on SocketException {
      Get.snackbar(
        "Network Error",
        "No internet connection.",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return false;
    } on TimeoutException {
      Get.snackbar(
        "Timeout",
        "The server took too long to respond.",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return false;
    } catch (e, stack) {
      print("Login error: $e\n$stack");
      Get.snackbar(
        "Unexpected Error",
        "Something went wrong. Try again.",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
