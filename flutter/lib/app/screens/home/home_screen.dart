import 'package:chat_app/app/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/message_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/theme_selector_sheet.dart';

class HomeScreen extends StatelessWidget {
  final HomeController homeController = Get.put(HomeController());
  final ThemeController themeController = Get.find();
  final MessageController messageController = Get.put(MessageController());
  final AuthController authController = Get.find();

  final storage = GetStorage();
  final RxInt _selectedIndex = 0.obs;
  final RxBool showOnlineUsers = true.obs;

  HomeScreen({Key? key}) : super(key: key);

  void _onItemTapped(int index) {
    _selectedIndex.value = index;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  Widget _buildConnectionStatusBar() {
    return Obx(() {
      final status = homeController.connectionStatus.value;
      final color = homeController.getConnectionStatusColor();
      final text = homeController.getConnectionStatusText();

      if (status == 'connected') return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: color,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == 'connecting')
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            if (status == 'connecting') const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (status == 'failed') ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: homeController.reconnectSocket,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildMessagesTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUserId = storage.read('user_id');

    return Obx(() {
      if (homeController.isLoading.value && homeController.users.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading conversations...'),
            ],
          ),
        );
      }

      final allUsers =
          homeController.users.where((u) => u.id != currentUserId).toList();
      final filteredUsers =
          homeController.filteredUsers
              .where((u) => u.id != currentUserId)
              .toList();
      final onlineUsers =
          allUsers.where((u) => homeController.isUserOnline(u.id)).toList();

      return RefreshIndicator(
        onRefresh: homeController.refreshUsers,
        child: CustomScrollView(
          slivers: [
            // Connection Status Bar
            SliverToBoxAdapter(child: _buildConnectionStatusBar()),

            // Header Section with enhanced design
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Messages",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Obx(() {
                          final onlineCount =
                              homeController.onlineUserIds.length;
                          return Text(
                            "$onlineCount users online",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }),
                      ],
                    ),
                    Row(
                      children: [
                        // Connection status indicator
                        Obx(() {
                          final color =
                              homeController.getConnectionStatusColor();
                          return Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                        // Notification badge
                        Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: colorScheme.primary,
                                size: 28,
                              ),
                              onPressed: () {
                                Get.snackbar(
                                  'Notifications',
                                  'You have ${homeController.unreadCount.value} unread messages',
                                  snackPosition: SnackPosition.TOP,
                                  duration: const Duration(seconds: 2),
                                );
                              },
                            ),
                            Obx(() {
                              if (homeController.unreadCount.value > 0) {
                                return Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    child: Text(
                                      homeController.unreadCount.value > 99
                                          ? '99+'
                                          : '${homeController.unreadCount.value}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Enhanced Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search conversations...",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      suffixIcon: Obx(() {
                        return homeController.searchQuery.value.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: homeController.clearSearch,
                            )
                            : const SizedBox.shrink();
                      }),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    onChanged: homeController.updateSearchQuery,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Enhanced Online Users Section
            if (onlineUsers.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Online (${onlineUsers.length})",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              showOnlineUsers.value
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: colorScheme.primary,
                            ),
                            onPressed: () => showOnlineUsers.toggle(),
                          ),
                        ],
                      ),
                    ),
                    if (showOnlineUsers.value) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: onlineUsers.length,
                          itemBuilder: (context, index) {
                            final user = onlineUsers[index];
                            return GestureDetector(
                              onTap: () {
                                homeController.markMessagesAsRead(user.id);
                                Get.toNamed(
                                  '/ChatScreen/${user.id}/${Uri.encodeComponent(user.fullName)}',
                                  arguments: {
                                    'userId': user.id,
                                    'userName': user.fullName,
                                  },
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 16),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.green,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 28,
                                            backgroundColor: colorScheme.primary
                                                .withOpacity(0.1),
                                            backgroundImage:
                                                user.profilePic != null
                                                    ? NetworkImage(
                                                      user.profilePic!,
                                                    )
                                                    : null,
                                            child:
                                                user.profilePic == null
                                                    ? Text(
                                                      user.fullName.isNotEmpty
                                                          ? user.fullName[0]
                                                              .toUpperCase()
                                                          : '',
                                                      style: TextStyle(
                                                        color:
                                                            colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    )
                                                    : null,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        user.fullName.split(" ").first,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Recent Chats Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Recent Chats",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Enhanced Chat List
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final user = filteredUsers[index];
                final isOnline = homeController.isUserOnline(user.id);
                final hasUnread = user.unreadCount > 0;
                final isTyping = user.isTyping;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        hasUnread
                            ? colorScheme.primary.withOpacity(0.05)
                            : colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        hasUnread
                            ? Border.all(
                              color: colorScheme.primary.withOpacity(0.2),
                            )
                            : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: Stack(
                      children: [
                        Hero(
                          tag: 'avatar_${user.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.1,
                              ),
                              backgroundImage:
                                  user.profilePic != null
                                      ? NetworkImage(user.profilePic!)
                                      : null,
                              child:
                                  user.profilePic == null
                                      ? Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName[0].toUpperCase()
                                            : '',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      )
                                      : null,
                            ),
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: TextStyle(
                              fontWeight:
                                  hasUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (user.lastMessageTime != null)
                          Text(
                            _formatTime(user.lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  hasUnread
                                      ? colorScheme.primary
                                      : Colors.grey.shade600,
                              fontWeight:
                                  hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        if (isTyping)
                          Row(
                            children: [
                              Text(
                                "Typing",
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 24,
                                height: 12,
                                child: Row(
                                  children: List.generate(
                                    3,
                                    (i) => Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            user.lastMessage?.isNotEmpty == true
                                ? user.lastMessage!
                                : "Tap to start chatting...",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  user.lastMessage?.isNotEmpty == true
                                      ? (hasUnread
                                          ? colorScheme.onSurface.withOpacity(
                                            0.8,
                                          )
                                          : Colors.grey.shade600)
                                      : Colors.grey.shade500,
                              fontWeight:
                                  hasUnread
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              user.unreadCount > 99
                                  ? '99+'
                                  : user.unreadCount.toString(),
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                      ],
                    ),
                    onTap: () {
                      homeController.markMessagesAsRead(user.id);
                      Get.toNamed(
                        '/ChatScreen/${user.id}/${Uri.encodeComponent(user.fullName)}',
                        arguments: {
                          'userId': user.id,
                          'userName': user.fullName,
                        },
                      );
                    },
                  ),
                );
              }, childCount: filteredUsers.length),
            ),

            // Enhanced Empty State
            if (filteredUsers.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            homeController.searchQuery.value.isNotEmpty
                                ? Icons.search_off
                                : Icons.chat_bubble_outline,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          homeController.searchQuery.value.isNotEmpty
                              ? "No users found"
                              : "No conversations yet",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          homeController.searchQuery.value.isNotEmpty
                              ? "Try searching with a different term"
                              : "Start a conversation with someone!",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (homeController.searchQuery.value.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: homeController.clearSearch,
                            child: const Text('Clear Search'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // Add some bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      );
    });
  }

  Widget _buildSettingsTab(BuildContext context) {
    final user = authController.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Enhanced Profile Section
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        backgroundImage:
                            user['profilePic'] != null
                                ? NetworkImage(user['profilePic'])
                                : null,
                        child:
                            user['profilePic'] == null
                                ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: colorScheme.primary,
                                )
                                : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  user['fullName'] ?? 'User',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user['email'] ?? 'user@example.com',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                // Connection status in profile
                Obx(() {
                  final status = homeController.connectionStatus.value;
                  final color = homeController.getConnectionStatusColor();
                  final text = homeController.getConnectionStatusText();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          text,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Enhanced Settings Options
          _buildSettingsOption(
            context,
            icon: Icons.person_outline,
            title: "Edit Profile",
            subtitle: "Update your personal information",
            onTap: () {
              Get.snackbar(
                'Coming Soon',
                'Profile editing will be available soon!',
              );
            },
          ),

          _buildSettingsOption(
            context,
            icon: Icons.palette_outlined,
            title: "Appearance",
            subtitle: "Customize your theme and colors",
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => showThemeSelectorSheet(),
              );
            },
          ),

          _buildSettingsOption(
            context,
            icon: Icons.notifications_outlined,
            title: "Notifications",
            subtitle: "Manage your notification preferences",
            trailing: Obx(
              () => Text(
                '${homeController.unreadCount.value} unread',
                style: TextStyle(
                  color:
                      homeController.unreadCount.value > 0
                          ? Colors.red
                          : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onTap: () {
              Get.snackbar(
                'Coming Soon',
                'Notification settings will be available soon!',
              );
            },
          ),

          _buildSettingsOption(
            context,
            icon: Icons.wifi_outlined,
            title: "Connection",
            subtitle: "Manage your connection settings",
            trailing: Obx(() {
              final color = homeController.getConnectionStatusColor();
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              );
            }),
            onTap: () {
              if (homeController.connectionStatus.value != 'connected') {
                homeController.reconnectSocket();
              } else {
                Get.snackbar(
                  'Connection Status',
                  'You are connected to the chat server',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
          ),

          _buildSettingsOption(
            context,
            icon: Icons.privacy_tip_outlined,
            title: "Privacy & Security",
            subtitle: "Control your privacy settings",
            onTap: () {
              Get.snackbar(
                'Coming Soon',
                'Privacy settings will be available soon!',
              );
            },
          ),

          _buildSettingsOption(
            context,
            icon: Icons.help_outline,
            title: "Help & Support",
            subtitle: "Get help and contact support",
            onTap: () {
              Get.snackbar(
                'Help',
                'For support, please contact us at support@example.com',
              );
            },
          ),

          _buildSettingsOption(
            context,
            icon: Icons.info_outline,
            title: "About",
            subtitle: "App version and information",
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "Let's Chat",
                applicationVersion: "1.0.0",
                applicationIcon: Icon(
                  Icons.chat,
                  size: 48,
                  color: colorScheme.primary,
                ),
                children: [
                  const Text(
                    "A modern real-time chat application built with Flutter.",
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // Enhanced Logout Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [colorScheme.error, colorScheme.error.withOpacity(0.8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.error.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text("Logout"),
                        content: const Text("Are you sure you want to logout?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              authController.logout();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Logout"),
                          ),
                        ],
                      ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        trailing:
            trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = authController.currentUser;

    final tabs = [_buildMessagesTab(context), _buildSettingsTab(context)];

    return Obx(
      () => Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          title: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    user['fullName']?.isNotEmpty == true
                        ? user['fullName'][0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Let's Chat",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            if (_selectedIndex.value == 0) ...[
              // Connection status indicator
              Obx(() {
                final color = homeController.getConnectionStatusColor();
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onPressed: () {
                      final status = homeController.getConnectionStatusText();
                      Get.snackbar(
                        'Connection Status',
                        status,
                        backgroundColor: color,
                        colorText: Colors.white,
                      );
                    },
                  ),
                );
              }),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: homeController.refreshUsers,
              ),
            ],
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: IndexedStack(
            index: _selectedIndex.value,
            key: ValueKey<int>(_selectedIndex.value),
            children: tabs,
          ),
        ),
        bottomNavigationBar: Obx(
          () => Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex.value,
              onTap: _onItemTapped,
              selectedItemColor: colorScheme.primary,
              unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
              backgroundColor: colorScheme.surface,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      const Icon(Icons.message_outlined),
                      Obx(() {
                        if (homeController.unreadCount.value > 0) {
                          return Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 12,
                                minHeight: 12,
                              ),
                              child: Text(
                                homeController.unreadCount.value > 9
                                    ? '9+'
                                    : homeController.unreadCount.value
                                        .toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                  activeIcon: const Icon(Icons.message),
                  label: 'Messages',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
