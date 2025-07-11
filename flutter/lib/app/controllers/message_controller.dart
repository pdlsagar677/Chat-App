import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import '../services/socket_service.dart';

class MessageController extends GetxController {
  final storage = GetStorage();
  final chatMessages = <Map<String, dynamic>>[].obs;
  final recentChats = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final isTyping = false.obs;
  final isUserTyping = false.obs;
  final isUserOnline = false.obs;

  // Enhanced deduplication with timestamp tracking
  final Map<String, int> _messageTimestamps = {};
  final Set<String> _processedMessageIds = {};
  final Set<String> _joinedRooms = {};
  Timer? _typingDebounce;
  Timer? _uiUpdateTimer;

  late final SocketService socketService;
  String? currentChatUserId;
  String get currentUserId => storage.read('user_id') ?? '';
  final String baseUrl = 'http://172.16.3.128:5001/api';

  // UI update batching
  bool _pendingUIUpdate = false;
  final List<Map<String, dynamic>> _pendingMessages = [];

  @override
  void onInit() {
    super.onInit();
    socketService = Get.find<SocketService>();
    _setupSocketListeners();
    _initializeSocket();
    _startUIUpdateTimer();
  }

  void _startUIUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      if (_pendingUIUpdate && _pendingMessages.isNotEmpty) {
        _processPendingMessages();
        _pendingUIUpdate = false;
      }
    });
  }

  void _processPendingMessages() {
    for (final message in _pendingMessages) {
      _addMessageToChatInternal(message);
    }
    _pendingMessages.clear();
    chatMessages.refresh();
  }

  Future<void> _initializeSocket() async {
    try {
      final userId = currentUserId;
      final token = storage.read('auth_token') ?? '';

      if (userId.isNotEmpty && token.isNotEmpty) {
        await socketService.initSocket(userId: userId, token: token);
        print('[MessageController] ✅ Socket initialized successfully');
      } else {
        print(
          '[MessageController] ⚠️ Missing credentials for socket initialization',
        );
      }
    } catch (e) {
      print('[MessageController] ❌ Failed to initialize socket: $e');
    }
  }

  void _setupSocketListeners() {
    print('[MessageController] Setting up socket listeners...');

    // Enhanced message handling with deduplication
    socketService.onNewMessage(_onMessageReceived);
    socketService.onTyping(_onTyping);
    socketService.onStoppedTyping(_onStoppedTyping);
    socketService.onMessageSeen(_onSeen);
    socketService.onReactionReceived(_onReaction);

    // Online status updates
    socketService.onOnlineUsersUpdated((List<String> onlineIds) {
      print('[MessageController] 👥 Online users updated: $onlineIds');
      if (currentChatUserId != null) {
        final wasOnline = isUserOnline.value;
        isUserOnline.value = onlineIds.contains(currentChatUserId);

        if (wasOnline != isUserOnline.value) {
          print(
            '[MessageController] User $currentChatUserId online status changed: ${isUserOnline.value}',
          );
        }
      }
    });

    // Room events
    socketService.onRoomJoined((data) {
      print('[MessageController] 🏠 Room joined successfully: $data');
    });

    socketService.onUserJoined((data) {
      print('[MessageController] 👤 User joined room: $data');
    });

    socketService.onUserLeft((data) {
      print('[MessageController] 👤 User left room: $data');
    });
  }

  void _onMessageReceived(Map<String, dynamic> data) {
    print('[MessageController] 🔔 Received socket message: $data');

    try {
      final msg = _normalizeMessage(data);
      final id = msg['id']?.toString();
      final timestamp = msg['localTimestamp'] as int?;

      // Enhanced deduplication logic
      if (id == null || _isDuplicateMessage(id, timestamp)) {
        print(
          '[MessageController] 🚫 Duplicate message detected, skipping: $id',
        );
        return;
      }

      final sender = msg['senderId']?.toString();
      final receiver = msg['receiverId']?.toString();

      if (sender == null || receiver == null) {
        print('[MessageController] ⚠️ Invalid sender or receiver');
        return;
      }

      final isRelevant = _isMessageRelevant(sender, receiver);

      print(
        '[MessageController] Message relevance check: sender=$sender, receiver=$receiver, currentChat=$currentChatUserId, isRelevant=$isRelevant',
      );

      if (isRelevant) {
        // Add to pending messages for batch processing
        _pendingMessages.add(msg);
        _pendingUIUpdate = true;

        // Mark as processed
        _processedMessageIds.add(id);
        if (timestamp != null) {
          _messageTimestamps[id] = timestamp;
        }

        print('[MessageController] ✅ Message queued for UI update');
      }

      // Update recent chats for any message involving current user
      if (sender == currentUserId || receiver == currentUserId) {
        _updateRecentChat(msg);
      }
    } catch (e) {
      print('[MessageController] ❌ Error processing received message: $e');
    }
  }

  bool _isDuplicateMessage(String id, int? timestamp) {
    // Check if we've already processed this message ID
    if (_processedMessageIds.contains(id)) {
      return true;
    }

    // Check if message already exists in chat
    final existsInChat = chatMessages.any((m) => m['id']?.toString() == id);
    if (existsInChat) {
      return true;
    }

    // Check timestamp-based deduplication for messages with same content
    if (timestamp != null && _messageTimestamps.containsKey(id)) {
      final existingTimestamp = _messageTimestamps[id]!;
      if ((timestamp - existingTimestamp).abs() < 1000) {
        // Within 1 second
        return true;
      }
    }

    return false;
  }

  void _onTyping(Map<String, dynamic> data) {
    print('[MessageController] ✍️ Typing event: $data');
    final fromUserId = data['from']?.toString() ?? data['userId']?.toString();

    if (fromUserId == currentChatUserId) {
      isTyping.value = true;
      isUserTyping.value = true;

      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        isTyping.value = false;
        isUserTyping.value = false;
      });
    }
  }

  void _onStoppedTyping(Map<String, dynamic> data) {
    print('[MessageController] ✍️ Stopped typing event: $data');
    final fromUserId = data['from']?.toString() ?? data['userId']?.toString();

    if (fromUserId == currentChatUserId) {
      isTyping.value = false;
      isUserTyping.value = false;
      _typingDebounce?.cancel();
    }
  }

  void _onSeen(Map<String, dynamic> data) {
    final messageId = data['messageId']?.toString();
    if (messageId != null) {
      _updateMessageStatus(messageId, 'seen');
    }
  }

  void _onReaction(Map<String, dynamic> data) {
    final messageId = data['messageId']?.toString();
    final emoji = data['reaction']?.toString();

    if (messageId != null && emoji != null) {
      final index = chatMessages.indexWhere(
        (m) => m['id']?.toString() == messageId,
      );
      if (index != -1) {
        chatMessages[index]['reaction'] = emoji;
        chatMessages.refresh();
      }
    }
  }

  bool _isMessageRelevant(String sender, String receiver) {
    final relevant =
        (sender == currentChatUserId && receiver == currentUserId) ||
        (sender == currentUserId && receiver == currentChatUserId);

    print(
      '[MessageController] Checking relevance: sender=$sender, receiver=$receiver, currentChat=$currentChatUserId, currentUser=$currentUserId, result=$relevant',
    );
    return relevant;
  }

  void _updateMessageStatus(String messageId, String status) {
    final index = chatMessages.indexWhere(
      (m) => m['id']?.toString() == messageId,
    );
    if (index != -1) {
      chatMessages[index]['status'] = status;
      chatMessages.refresh();
    }
  }

  void _updateRecentChat(Map<String, dynamic> message) {
    final senderId = message['senderId']?.toString();
    final receiverId = message['receiverId']?.toString();

    if (senderId == null || receiverId == null) return;

    final otherUserId = senderId == currentUserId ? receiverId : senderId;
    final existingIndex = recentChats.indexWhere(
      (chat) => chat['userId'] == otherUserId,
    );

    final chatItem = {
      'userId': otherUserId,
      'userName': message['senderName'] ?? 'Unknown',
      'lastMessage': message['text'] ?? 'File attachment',
      'timestamp': message['timestamp'],
      'unreadCount': senderId != currentUserId ? 1 : 0,
    };

    if (existingIndex != -1) {
      recentChats[existingIndex] = chatItem;
    } else {
      recentChats.insert(0, chatItem);
    }

    recentChats.refresh();
  }

  void startConversation(String userId) {
    print('[MessageController] 🚀 Starting conversation with: $userId');

    if (currentChatUserId != userId) {
      // Clear previous conversation state
      chatMessages.clear();
      _processedMessageIds.clear();
      _messageTimestamps.clear();
      _pendingMessages.clear();
      isTyping.value = false;
      isUserTyping.value = false;
      _typingDebounce?.cancel();
    }

    currentChatUserId = userId;
    final room = _generateRoomId(currentUserId, userId);

    print('[MessageController] 🏠 Joining room: $room');

    // Join the room for real-time updates
    socketService.joinRoom(room, userId: currentUserId);
    _joinedRooms.add(room);

    // Fetch existing messages
    fetchMessages(userId);
  }

  Future<void> fetchMessages(String userId) async {
    if (isLoading.value) return;

    print('[MessageController] 📥 Fetching messages for user: $userId');
    isLoading.value = true;

    try {
      final token = storage.read('auth_token');
      final response = await http
          .get(
            Uri.parse('$baseUrl/messages/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rawMessages = json.decode(response.body);
        final processedMessages = _processMessages(rawMessages);

        // Clear and update chat messages
        chatMessages.clear();
        _processedMessageIds.clear();
        _messageTimestamps.clear();

        for (final message in processedMessages) {
          final id = message['id']?.toString();
          final timestamp = message['localTimestamp'] as int?;

          if (id != null) {
            _processedMessageIds.add(id);
            if (timestamp != null) {
              _messageTimestamps[id] = timestamp;
            }
          }
        }

        chatMessages.assignAll(processedMessages);
        print(
          '[MessageController] 📥 Loaded ${processedMessages.length} messages',
        );

        // Mark messages as seen
        markMessagesAsSeen(userId);
      } else {
        print(
          '[MessageController] ❌ Failed to fetch messages: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[MessageController] ❌ fetchMessages error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> _processMessages(List<dynamic> rawMessages) {
    final Set<String> seenIds = {};
    final List<Map<String, dynamic>> processedMessages = [];

    for (var item in rawMessages) {
      final msg = _normalizeMessage(Map<String, dynamic>.from(item));
      final id = msg['id']?.toString();

      if (id == null || seenIds.contains(id)) continue;

      seenIds.add(id);
      processedMessages.add(msg);
    }

    // Sort by timestamp
    processedMessages.sort((a, b) {
      final aTime = _parseTimestamp(a['timestamp']);
      final bTime = _parseTimestamp(b['timestamp']);
      return aTime.compareTo(bTime);
    });

    return processedMessages;
  }

  Future<bool> sendMessage(
    String receiverId,
    String text, {
    String? base64Image,
    String? base64File,
    String? fileName,
    String? mimeType,
    String? replyToMessageId,
    String? reaction,
  }) async {
    if (receiverId.isEmpty) return false;

    print('[MessageController] 📤 Sending message to: $receiverId');

    try {
      final token = storage.read('auth_token');
      final now = DateTime.now();

      final messageData = {
        'text': text,
        'senderId': currentUserId,
        'receiverId': receiverId,
        'status': 'sent',
        'timestamp': now.toIso8601String(),
        'localTimestamp': now.millisecondsSinceEpoch,
        if (base64Image?.isNotEmpty ?? false) 'image': base64Image,
        if (base64File != null) ...{
          'file': base64File,
          'fileName': fileName,
          'mimeType': mimeType,
        },
        if (replyToMessageId != null) 'replyTo': replyToMessageId,
        if (reaction != null) 'reaction': reaction,
      };

      // Add message locally first for instant feedback
      final tempId = 'temp_${now.millisecondsSinceEpoch}';
      final tempMessage = {...messageData, 'id': tempId, 'status': 'sending'};

      // Add to chat immediately for instant UI feedback
      _addMessageToChat(tempMessage);

      // Send via socket for real-time delivery
      print('[MessageController] 📡 Sending message via socket');
      socketService.sendMessage(messageData);

      // Send to server via HTTP for persistence
      final response = await http
          .post(
            Uri.parse('$baseUrl/messages/send/$receiverId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(messageData),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final serverMessage = _normalizeMessage(responseData);

        // Replace temp message with server message
        final tempIndex = chatMessages.indexWhere((m) => m['id'] == tempId);
        if (tempIndex != -1) {
          chatMessages[tempIndex] = serverMessage;

          // Update tracking
          _processedMessageIds.remove(tempId);
          final serverId = serverMessage['id']?.toString();
          if (serverId != null) {
            _processedMessageIds.add(serverId);
            final timestamp = serverMessage['localTimestamp'] as int?;
            if (timestamp != null) {
              _messageTimestamps[serverId] = timestamp;
            }
          }

          chatMessages.refresh();
        }

        print('[MessageController] ✅ Message sent successfully');
        return true;
      } else {
        // Remove temp message on failure
        _removeMessageById(tempId);
        print(
          '[MessageController] ❌ Failed to send message: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('[MessageController] ❌ sendMessage error: $e');
      return false;
    }
  }

  Future<bool> sendFile(
    String receiverId,
    String base64File,
    String fileName,
    String mimeType, {
    String? text,
  }) async {
    return await sendMessage(
      receiverId,
      text ?? 'Sent a file: $fileName',
      base64File: base64File,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  void sendTypingEvent(String receiverId) {
    if (receiverId.isEmpty) return;

    print('[MessageController] ✍️ Sending typing event to: $receiverId');

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      socketService.sendTypingEvent(receiverId);
    });
  }

  void sendStoppedTypingEvent(String receiverId) {
    if (receiverId.isEmpty) return;

    print(
      '[MessageController] ✍️ Sending stopped typing event to: $receiverId',
    );

    _typingDebounce?.cancel();
    socketService.sendStoppedTypingEvent(receiverId);
  }

  void sendReaction(String messageId, String emoji) {
    if (messageId.isEmpty || emoji.isEmpty) return;

    final index = chatMessages.indexWhere(
      (m) => m['id']?.toString() == messageId,
    );
    if (index != -1) {
      // Update locally first
      chatMessages[index]['reaction'] = emoji;
      chatMessages.refresh();

      // Send to server via socket
      socketService.sendReaction(messageId, emoji);
    }
  }

  void markMessagesAsSeen(String userId) {
    if (userId.isEmpty) return;

    final unseenMessages =
        chatMessages
            .where(
              (m) =>
                  m['receiverId'] == currentUserId &&
                  m['senderId'] == userId &&
                  m['status'] != 'seen',
            )
            .toList();

    if (unseenMessages.isNotEmpty) {
      // Update locally
      for (final message in unseenMessages) {
        message['status'] = 'seen';
      }
      chatMessages.refresh();

      // Notify server
      final lastMessageId = unseenMessages.last['id']?.toString();
      if (lastMessageId != null) {
        socketService.markMessageAsSeen(userId, lastMessageId);
      }
    }
  }

  void _addMessageToChat(Map<String, dynamic> message) {
    final normalized = _normalizeMessage(message);
    final id = normalized['id']?.toString();

    if (id == null) return;

    // Check for duplicates
    if (_processedMessageIds.contains(id) ||
        chatMessages.any((m) => m['id']?.toString() == id)) {
      return;
    }

    _addMessageToChatInternal(normalized);
    _processedMessageIds.add(id);

    final timestamp = normalized['localTimestamp'] as int?;
    if (timestamp != null) {
      _messageTimestamps[id] = timestamp;
    }

    chatMessages.refresh();
  }

  void _addMessageToChatInternal(Map<String, dynamic> message) {
    // Find correct position to maintain chronological order
    final newTimestamp = _parseTimestamp(message['timestamp']);
    int insertIndex = chatMessages.length;

    for (int i = chatMessages.length - 1; i >= 0; i--) {
      final existingTimestamp = _parseTimestamp(chatMessages[i]['timestamp']);
      if (newTimestamp.isAfter(existingTimestamp)) {
        insertIndex = i + 1;
        break;
      }
      if (i == 0) {
        insertIndex = 0;
      }
    }

    if (insertIndex >= chatMessages.length) {
      chatMessages.add(message);
    } else {
      chatMessages.insert(insertIndex, message);
    }
  }

  void _removeMessageById(String messageId) {
    final index = chatMessages.indexWhere(
      (m) => m['id']?.toString() == messageId,
    );
    if (index != -1) {
      chatMessages.removeAt(index);
      _processedMessageIds.remove(messageId);
      _messageTimestamps.remove(messageId);
      chatMessages.refresh();
    }
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> message) {
    // Handle ID normalization
    final id = message['id'] ?? message['_id'];
    message['id'] = id?.toString();

    // Handle timestamp normalization
    final timestamp = message['timestamp'] ?? message['createdAt'];
    if (timestamp != null) {
      final parsedTime = _parseTimestamp(timestamp.toString());
      message['timestamp'] = parsedTime.toIso8601String();
      message['localTimestamp'] = parsedTime.millisecondsSinceEpoch;
    } else {
      final now = DateTime.now();
      message['timestamp'] = now.toIso8601String();
      message['localTimestamp'] = now.millisecondsSinceEpoch;
    }

    // Ensure required fields
    message['status'] = message['status'] ?? 'sent';
    message['senderId'] = message['senderId']?.toString() ?? '';
    message['receiverId'] = message['receiverId']?.toString() ?? '';
    message['text'] = message['text'] ?? '';

    return message;
  }

  DateTime _parseTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return DateTime.now();

    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      try {
        final ms = int.tryParse(timestamp);
        if (ms != null) {
          return DateTime.fromMillisecondsSinceEpoch(ms);
        }
      } catch (e) {
        final seconds = double.tryParse(timestamp);
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
        }
      }
    }

    return DateTime.now();
  }

  String _generateRoomId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return 'chat_${sorted.join("_")}';
  }

  Future<void> fetchRecentChats() async {
    try {
      final token = storage.read('auth_token');
      final response = await http
          .get(
            Uri.parse('$baseUrl/messages/recent/$currentUserId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rawChats = json.decode(response.body);
        recentChats.value = rawChats.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('[MessageController] ❌ fetchRecentChats error: $e');
    }
  }

  void deleteMessage(String messageId) {
    try {
      _removeMessageById(messageId);
      print('[MessageController] Message deleted locally: $messageId');
    } catch (e) {
      print('[MessageController] ❌ deleteMessage error: $e');
    }
  }

  void clearChat(String userId) {
    try {
      chatMessages.clear();
      _processedMessageIds.clear();
      _messageTimestamps.clear();
      _pendingMessages.clear();
      print('[MessageController] Chat cleared for user: $userId');
    } catch (e) {
      print('[MessageController] ❌ clearChat error: $e');
    }
  }

  void clearCurrentChat() {
    currentChatUserId = null;
    chatMessages.clear();
    _processedMessageIds.clear();
    _messageTimestamps.clear();
    _pendingMessages.clear();
    isTyping.value = false;
    isUserTyping.value = false;
    _typingDebounce?.cancel();
  }

  @override
  void onClose() {
    _typingDebounce?.cancel();
    _uiUpdateTimer?.cancel();
    super.onClose();
  }
}
