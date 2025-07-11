import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';

import '../models/user_model.dart';

class UsersController extends GetxController {
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<String> onlineUserIds =
      <String>[].obs; // List of userIds currently online
  final RxBool isLoading = false.obs;

  final storage = GetStorage();
  final String baseUrl =
      "http://172.16.3.128:5001/api/users"; // Replace with your API URL

  /// Updates the online users list from socket event
  void updateOnlineUsers(List<String> userIds) {
    onlineUserIds.assignAll(userIds);
  }

  /// Returns true if the given userId is currently online
  bool isUserOnline(String userId) {
    return onlineUserIds.contains(userId);
  }

  /// Fetch users from backend API with proper authorization
  Future<void> fetchUsers() async {
    final token = storage.read('auth_token');
    if (token == null || token.isEmpty) {
      Get.snackbar(
        "Unauthorized",
        "Please login first",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    try {
      isLoading.value = true;

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        users.value = data.map((json) => UserModel.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        Get.snackbar(
          "Unauthorized",
          "Session expired, please login again",
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        await storage.erase();
        Get.offAllNamed('/LoginScreen');
      } else {
        Get.snackbar(
          "Error",
          "Failed to fetch users. Status: ${response.statusCode}",
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "An unexpected error occurred: $e",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
