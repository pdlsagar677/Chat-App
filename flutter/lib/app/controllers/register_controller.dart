import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';

class RegisterController extends GetxController {
  // Form controllers
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // UI state
  final isPasswordHidden = true.obs;
  final isLoading = false.obs;

  // Validation messages
  final fullNameError = RxnString();
  final emailError = RxnString();
  final passwordError = RxnString();
  final confirmPasswordError = RxnString();

  // Storage (e.g., for JWT token)
  final storage = GetStorage();

  // Validators
  bool validateFullName(String value) {
    if (value.trim().isEmpty) {
      fullNameError.value = "Full name is required";
      return false;
    }
    fullNameError.value = null;
    return true;
  }

  bool validateEmail(String value) {
    if (value.trim().isEmpty || !GetUtils.isEmail(value.trim())) {
      emailError.value = "Enter a valid email";
      return false;
    }
    emailError.value = null;
    return true;
  }

  bool validatePassword(String value) {
    if (value.isEmpty || value.length < 6) {
      passwordError.value = "Password must be at least 6 characters";
      return false;
    }
    passwordError.value = null;
    return true;
  }

  bool validateConfirmPassword(String value) {
    if (value != passwordController.text) {
      confirmPasswordError.value = "Passwords do not match";
      return false;
    }
    confirmPasswordError.value = null;
    return true;
  }

  bool validateAll() {
    final fullNameValid = validateFullName(fullNameController.text.trim());
    final emailValid = validateEmail(emailController.text.trim());
    final passwordValid = validatePassword(passwordController.text.trim());
    final confirmValid = validateConfirmPassword(
      confirmPasswordController.text.trim(),
    );
    return fullNameValid && emailValid && passwordValid && confirmValid;
  }

  Future<void> registerUser() async {
    if (!validateAll()) return;

    final url = Uri.parse("http://172.16.7.243:5001/api/auth/signup");

    try {
      isLoading.value = true;

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullNameController.text.trim(),
              'email': emailController.text.trim(),
              'password': passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.headers['content-type']?.contains('application/json') ??
          false) {
        final data = jsonDecode(response.body);

        if (response.statusCode == 201) {
          final token = data['token'];
          if (token != null) {
            await storage.write('auth_token', token);
          }

          Get.snackbar(
            "Success",
            "Registration successful!",
            snackPosition: SnackPosition.TOP,
          );
          Get.offAllNamed('/HomeScreen');
        } else {
          Get.snackbar(
            "Registration Failed",
            data["message"] ?? "Something went wrong.",
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
          );
        }
      } else {
        Get.snackbar(
          "Error",
          "Unexpected response from server.",
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
      }
    } on TimeoutException {
      Get.snackbar(
        "Timeout",
        "The request timed out. Please try again.",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } catch (e, stackTrace) {
      print('Register error: $e');
      print('Stack trace: $stackTrace');
      Get.snackbar(
        "Error",
        "Something went wrong. Try again later.",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
