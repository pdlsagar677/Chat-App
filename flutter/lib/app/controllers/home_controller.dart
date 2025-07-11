import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'dart:async';

import '../services/socket_service.dart';
import '../models/user_model.dart';

class HomeController extends GetxController {
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<String> onlineUserIds = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxInt unreadCount = 0.obs;
  final RxString searchQuery = ''.obs;
  final RxString connectionStatus = 'disconnected'.obs;

  final storage = GetStorage();
  late final SocketService socketService;
  Timer? _periodicRefreshTimer;

  String? get currentUserId => storage.read('user_id');
  String get baseUrl => 'http://172.16.3.128:5001/api';

  @override
  void onInit() {
    super.onInit();
    _initializeSocket();
    fetchUsers();
    _startPeriodicRefresh();
  }

  @override
  void onClose() {
    _periodicRefreshTimer?.cancel();
    super.onClose();
  }

  /// Initialize socket and setup comprehensive event listeners
  Future<void> _initializeSocket() async {
    try {
      socketService = Get.find<SocketService>();

      // Listen to connection status changes
      ever(socketService.isConnectedObs, (bool isConnected) {
        connectionStatus.value = isConnected ? 'connected' : 'disconnected';
      });

      // Setup all socket event listeners
      _setupSocketListeners();

      // Initialize socket connection if credentials are available
      final userId = currentUserId ?? '';
      final token = storage.read('auth_token') ?? '';

      if (userId.isNotEmpty && token.isNotEmpty) {
        await socketService.initSocket(userId: userId, token: token);
        print('[HomeController] ✅ Socket initialized for user: $userId');
      }
    } catch (e) {
      print('[HomeController] ❌ Socket initialization error: $e');
    }
  }

  void _setupSocketListeners() {
    print('[HomeController] 🔧 Setting up socket listeners...');

    // Online users update event
    socketService.onOnlineUsersUpdated((List<String> onlineIds) {
      print('[HomeController] 👥 Online users updated: $onlineIds');
      onlineUserIds.assignAll(onlineIds);

      // Update user online status in the list
      for (int i = 0; i < users.length; i++) {
        final user = users[i];
        final isOnline = onlineIds.contains(user.id);
        if (user.isOnline != isOnline) {
          users[i] = UserModel(
            id: user.id,
            fullName: user.fullName,
            email: user.email,
            profilePic: user.profilePic,
            isAdmin: user.isAdmin,
            lastMessage: user.lastMessage,
            lastMessageTime: user.lastMessageTime,
            unreadCount: user.unreadCount,
            isTyping: user.isTyping,
            isOnline: isOnline,
          );
        }
      }
      users.refresh();
    });

    // New message event handler for home screen updates
    socketService.onNewMessage((data) {
      print('[HomeController] 📥 New message received: $data');
      _handleNewMessage(data);
    });

    // Typing indicator handlers
    socketService.onTyping((data) {
      print('[HomeController] ✍️ User typing: $data');
      _handleTypingIndicator(data, true);
    });

    socketService.onStoppedTyping((data) {
      print('[HomeController] ✍️ User stopped typing: $data');
      _handleTypingIndicator(data, false);
    });

    // Message seen handler
    socketService.onMessageSeen((data) {
      print('[HomeController] 👁️ Message seen: $data');
      _handleMessageSeen(data);
    });

    // Room events
    socketService.onUserJoined((data) {
      print('[HomeController] 👤 User joined room: $data');
    });

    socketService.onUserLeft((data) {
      print('[HomeController] 👤 User left room: $data');
    });
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final senderId = data['senderId'] as String? ?? '';
      final receiverId = data['receiverId'] as String? ?? '';
      final message = data['text'] as String? ?? '';
      final timeStr =
          data['timestamp'] as String? ?? data['createdAt'] as String? ?? '';

      // Only update if the message involves the current user
      if (senderId != currentUserId && receiverId != currentUserId) {
        return;
      }

      // Determine the other user ID
      final otherUserId = senderId == currentUserId ? receiverId : senderId;

      DateTime messageTime;
      try {
        messageTime = DateTime.parse(timeStr);
      } catch (_) {
        messageTime = DateTime.now();
      }

      // Find and update the user in the list
      final index = users.indexWhere((u) => u.id == otherUserId);
      if (index != -1) {
        final user = users[index];
        final isIncoming = senderId != currentUserId;

        final updatedUser = UserModel(
          id: user.id,
          fullName: user.fullName,
          email: user.email,
          profilePic: user.profilePic,
          isAdmin: user.isAdmin,
          lastMessage: message,
          lastMessageTime: messageTime,
          unreadCount: isIncoming ? user.unreadCount + 1 : user.unreadCount,
          isTyping: false, // Stop typing when message is received
          isOnline: user.isOnline,
        );

        users[index] = updatedUser;
        _sortUsersByLastMessage();
        _updateUnreadCount();

        print(
          '[HomeController] ✅ Updated user ${user.fullName} with new message',
        );
      } else {
        // If user not in list, refresh the entire list
        print('[HomeController] 🔄 User not found, refreshing user list');
        fetchUsers();
      }
    } catch (e) {
      print('[HomeController] ❌ Error handling new message: $e');
    }
  }

  void _handleTypingIndicator(Map<String, dynamic> data, bool isTyping) {
    try {
      final userId = data['from'] as String? ?? data['userId'] as String? ?? '';

      if (userId.isEmpty || userId == currentUserId) return;

      final index = users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        final user = users[index];
        final updatedUser = UserModel(
          id: user.id,
          fullName: user.fullName,
          email: user.email,
          profilePic: user.profilePic,
          isAdmin: user.isAdmin,
          lastMessage: user.lastMessage,
          lastMessageTime: user.lastMessageTime,
          unreadCount: user.unreadCount,
          isTyping: isTyping,
          isOnline: user.isOnline,
        );
        users[index] = updatedUser;
        users.refresh();
      }
    } catch (e) {
      print('[HomeController] ❌ Error handling typing indicator: $e');
    }
  }

  void _handleMessageSeen(Map<String, dynamic> data) {
    try {
      final fromUserId = data['from'] as String? ?? '';

      if (fromUserId.isEmpty) return;

      // Update message status for the user who saw the message
      final index = users.indexWhere((u) => u.id == fromUserId);
      if (index != -1) {
        // You can implement message status updates here if needed
        print('[HomeController] 👁️ Message seen by ${users[index].fullName}');
      }
    } catch (e) {
      print('[HomeController] ❌ Error handling message seen: $e');
    }
  }

  /// Fetch users list from API with enhanced error handling
  Future<void> fetchUsers() async {
    if (isLoading.value) return; // Prevent multiple simultaneous requests

    try {
      isLoading.value = true;
      final token = storage.read('auth_token');

      if (token == null) {
        print('[HomeController] ❌ No auth token available');
        return;
      }

      print('[HomeController] 📥 Fetching users from API...');

      final response = await http
          .get(
            Uri.parse('$baseUrl/users/all'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final loadedUsers = data.map((e) => UserModel.fromJson(e)).toList();

        // Filter out current user and update online status
        final filteredUsers =
            loadedUsers.where((u) => u.id != currentUserId).toList();

        // Update online status based on current online users
        for (int i = 0; i < filteredUsers.length; i++) {
          final user = filteredUsers[i];
          filteredUsers[i] = UserModel(
            id: user.id,
            fullName: user.fullName,
            email: user.email,
            profilePic: user.profilePic,
            isAdmin: user.isAdmin,
            lastMessage: user.lastMessage,
            lastMessageTime: user.lastMessageTime,
            unreadCount: user.unreadCount,
            isTyping: user.isTyping,
            isOnline: onlineUserIds.contains(user.id),
          );
        }

        users.assignAll(filteredUsers);
        _sortUsersByLastMessage();
        _updateUnreadCount();

        print('[HomeController] ✅ Loaded ${filteredUsers.length} users');
      } else {
        print(
          '[HomeController] ❌ Failed to fetch users: ${response.statusCode}',
        );
        _showError('Failed to load users. Please try again.');
      }
    } catch (e) {
      print('[HomeController] ❌ fetchUsers error: $e');
      _showError('Network error. Please check your connection.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh users with pull-to-refresh
  Future<void> refreshUsers() async {
    if (isRefreshing.value) return;

    try {
      isRefreshing.value = true;
      await fetchUsers();

      // Also refresh socket connection if needed
      if (!socketService.isConnected) {
        final userId = currentUserId ?? '';
        final token = storage.read('auth_token') ?? '';
        if (userId.isNotEmpty && token.isNotEmpty) {
          await socketService.connect();
        }
      }

      Get.snackbar(
        'Refreshed',
        'User list updated successfully',
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      print('[HomeController] ❌ refreshUsers error: $e');
      _showError('Failed to refresh. Please try again.');
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Start periodic refresh every 30 seconds
  void _startPeriodicRefresh() {
    _periodicRefreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (!isLoading.value && !isRefreshing.value) {
        print('[HomeController] 🔄 Periodic refresh triggered');
        fetchUsers();
      }
    });
  }

  /// Sort users by last message time descending
  void _sortUsersByLastMessage() {
    users.sort((a, b) {
      // First, prioritize users with unread messages
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (b.unreadCount > 0 && a.unreadCount == 0) return 1;

      // Then sort by last message time
      final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  /// Update global unread message count
  void _updateUnreadCount() {
    final newUnreadCount = users.fold(0, (sum, u) => sum + u.unreadCount);
    unreadCount.value = newUnreadCount;
    print('[HomeController] 📊 Total unread messages: $newUnreadCount');
  }

  /// Mark all messages as read for a given user
  void markMessagesAsRead(String otherUserId) {
    final index = users.indexWhere((u) => u.id == otherUserId);
    if (index != -1) {
      final user = users[index];
      if (user.unreadCount > 0) {
        final updatedUser = UserModel(
          id: user.id,
          fullName: user.fullName,
          email: user.email,
          profilePic: user.profilePic,
          isAdmin: user.isAdmin,
          lastMessage: user.lastMessage,
          lastMessageTime: user.lastMessageTime,
          unreadCount: 0, // Reset unread count
          isTyping: user.isTyping,
          isOnline: user.isOnline,
        );
        users[index] = updatedUser;
        _updateUnreadCount();

        // Mark as seen on server
        socketService.markMessageAsSeen(otherUserId, '');
        print(
          '[HomeController] ✅ Marked messages as read for ${user.fullName}',
        );
      }
    }
  }

  /// Send typing indicator event to server
  void sendTypingEvent(String toUserId) {
    socketService.sendTypingEvent(toUserId);
  }

  /// Send a new chat message
  void sendMessage(Map<String, dynamic> messageData) {
    socketService.sendMessage(messageData);
  }

  /// Get filtered users based on search query
  List<UserModel> get filteredUsers {
    if (searchQuery.value.isEmpty) {
      return users;
    }
    return users.where((user) {
      final name = user.fullName.toLowerCase();
      final email = user.email.toLowerCase();
      final query = searchQuery.value.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  /// Update search query
  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  /// Clear search query
  void clearSearch() {
    searchQuery.value = '';
  }

  /// Check if user is online
  bool isUserOnline(String userId) {
    return onlineUserIds.contains(userId);
  }

  /// Get connection status color
  Color getConnectionStatusColor() {
    switch (connectionStatus.value) {
      case 'connected':
        return Colors.green;
      case 'connecting':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get connection status text
  String getConnectionStatusText() {
    switch (connectionStatus.value) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      case 'failed':
        return 'Connection Failed';
      default:
        return 'Disconnected';
    }
  }

  /// Show error message
  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );
  }

  /// Force reconnect socket
  Future<void> reconnectSocket() async {
    try {
      final userId = currentUserId ?? '';
      final token = storage.read('auth_token') ?? '';

      if (userId.isNotEmpty && token.isNotEmpty) {
        await socketService.disconnect();
        await Future.delayed(Duration(seconds: 1));
        await socketService.initSocket(userId: userId, token: token);

        Get.snackbar(
          'Reconnected',
          'Successfully reconnected to chat server',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('[HomeController] ❌ Reconnect error: $e');
      _showError('Failed to reconnect. Please try again.');
    }
  }
}
