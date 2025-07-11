import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import '../services/socket_service.dart';

class AuthController extends GetxController {
  final storage = GetStorage();
  final RxBool isLoading = false.obs;
  final RxBool isLoggedIn = false.obs;

  final String baseUrl = 'http://172.16.3.39:5001/api';

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  void checkAuthStatus() {
    final token = storage.read('auth_token');
    final userId = storage.read('user_id');
    isLoggedIn.value = token != null && userId != null;
  }

  Future<bool> login(String email, String password) async {
    try {
      isLoading.value = true;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store user data
        await storage.write('auth_token', data['token']);
        await storage.write('user_id', data['user']['_id']);
        await storage.write('user_fullName', data['user']['fullName']);
        await storage.write('user_email', data['user']['email']);
        await storage.write('user_profilePic', data['user']['profilePic']);
        await storage.write('user_isAdmin', data['user']['isAdmin'] ?? false);

        isLoggedIn.value = true;

        // Initialize socket connection
        final socketService = Get.find<SocketService>();
        await socketService.initSocket(
          userId: data['user']['_id'],
          token: data['token'],
        );
        await socketService.connect();

        return true;
      } else {
        final error = json.decode(response.body);
        Get.snackbar('Login Failed', error['message'] ?? 'Invalid credentials');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Network error. Please try again.');
      print('Login error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register(String fullName, String email, String password) async {
    try {
      isLoading.value = true;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullName': fullName,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        Get.snackbar('Success', 'Account created successfully!');
        return true;
      } else {
        final error = json.decode(response.body);
        Get.snackbar(
          'Registration Failed',
          error['message'] ?? 'Registration failed',
        );
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Network error. Please try again.');
      print('Register error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      // Disconnect socket
      final socketService = Get.find<SocketService>();
      await socketService.disconnect();

      // Clear storage
      await storage.erase();

      isLoggedIn.value = false;

      // Navigate to login
      Get.offAllNamed('/LoginScreen');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // Get current user data
  Map<String, dynamic> get currentUser => {
    'id': storage.read('user_id'),
    'fullName': storage.read('user_fullName'),
    'email': storage.read('user_email'),
    'profilePic': storage.read('user_profilePic'),
    'isAdmin': storage.read('user_isAdmin'),
  };
}
