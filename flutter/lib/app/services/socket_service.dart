import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:async';

class SocketService extends GetxService {
  final String baseUrl;
  IO.Socket? _socket;

  // Connection state
  final RxBool _isConnected = false.obs;
  final RxBool _isConnecting = false.obs;
  final RxString _connectionStatus = 'disconnected'.obs;

  // User info
  String? _userId;
  String? _token;

  // Reconnection settings
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // Fixed: Better type safety for event listeners
  final Map<String, List<void Function(dynamic)>> _eventListeners = {};

  // Getters
  bool get isConnected => _isConnected.value;
  bool get isConnecting => _isConnecting.value;
  String get connectionStatus => _connectionStatus.value;
  IO.Socket? get socket => _socket;
  RxBool get isConnectedObs => _isConnected;

  SocketService({required this.baseUrl});

  @override
  void onInit() {
    super.onInit();
    _initializeConnectionStatusListener();
    _autoInitializeSocket();
  }

  @override
  void onClose() {
    _cleanupSocket();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.onClose();
  }

  void _initializeConnectionStatusListener() {
    _isConnected.listen((connected) {
      _connectionStatus.value = connected ? 'connected' : 'disconnected';
      if (connected) {
        _reconnectAttempts = 0;
        _startHeartbeat();
        _reattachListeners();
      } else {
        _heartbeatTimer?.cancel();
      }
    });
  }

  void _autoInitializeSocket() {
    try {
      final storage = GetStorage();
      final userId = storage.read('user_id');
      final token = storage.read('auth_token');

      if (userId != null && token != null) {
        print('[SocketService] 🚀 Auto-initializing socket for user: $userId');
        initSocket(userId: userId, token: token);
      }
    } catch (e) {
      print('[SocketService] ❌ Error auto-initializing socket: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected.value && _socket?.connected == true) {
        print('[SocketService] 💓 Sending heartbeat');
        _socket?.emit('ping');
      }
    });
  }

  Future<void> initSocket({
    required String userId,
    required String token,
  }) async {
    // Fixed: Better validation
    if (userId.trim().isEmpty || token.trim().isEmpty) {
      print('[SocketService] ❌ Missing or empty userId or token');
      throw ArgumentError('UserId and token must not be empty');
    }

    // If already connected with same credentials, return
    if (_isConnected.value && _userId == userId && _token == token) {
      print('[SocketService] ✅ Already connected with same credentials');
      return;
    }

    _userId = userId;
    _token = token;

    await _createSocket();
  }

  Future<void> _createSocket() async {
    if (_socket?.connected == true) {
      print('[SocketService] ⚠️ Disconnecting existing socket');
      _socket?.disconnect();
    }

    _isConnecting.value = true;

    try {
      print('[SocketService] 🔄 Creating socket connection to: $baseUrl');
      print('[SocketService] 🔐 Authenticating with userId: $_userId');

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(maxReconnectAttempts)
            .setReconnectionDelay(reconnectDelay.inMilliseconds)
            .setAuth({'userId': _userId!, 'token': _token!})
            .setTimeout(30000) // Fixed: Added timeout
            .build(),
      );

      _setupSocketListeners();
      print('[SocketService] 🔄 Socket initialized and connecting as $_userId');
    } catch (e) {
      _isConnecting.value = false;
      print('[SocketService] ❌ Failed to create socket: $e');
      rethrow;
    }
  }

  void _setupSocketListeners() {
    _socket?.onConnect((_) {
      _isConnected.value = true;
      _isConnecting.value = false;
      _reconnectAttempts = 0;
      print('[SocketService] 🔌 Connected successfully');
    });

    _socket?.onDisconnect((reason) {
      _isConnected.value = false;
      _isConnecting.value = false;
      print('[SocketService] ❌ Disconnected: $reason');

      if (reason != 'io client disconnect') {
        _attemptReconnection();
      }
    });

    _socket?.onConnectError((error) {
      _isConnected.value = false;
      _isConnecting.value = false;
      print('[SocketService] ⚠️ Connect Error: $error');
      _attemptReconnection();
    });

    _socket?.onError((error) {
      print('[SocketService] ⚠️ Socket Error: $error');
    });

    _socket?.onReconnect((attempt) {
      print('[SocketService] 🔄 Reconnected after $attempt attempts');
    });

    _socket?.onReconnectError((error) {
      print('[SocketService] ⚠️ Reconnection Error: $error');
    });

    _socket?.onReconnectFailed((_) {
      print(
        '[SocketService] ❌ Reconnection failed after $maxReconnectAttempts attempts',
      );
      _connectionStatus.value = 'failed';
    });

    _socket?.on('pong', (_) {
      print('[SocketService] 💓 Heartbeat received');
    });
  }

  // Fixed: More efficient listener reattachment
  void _reattachListeners() {
    for (final entry in _eventListeners.entries) {
      final event = entry.key;
      final callbacks = entry.value;

      for (final callback in callbacks) {
        _socket?.on(event, callback);
      }
    }
  }

  // Fixed: Better type safety
  void addListener(String event, void Function(dynamic) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, callback);
  }

  void _attemptReconnection() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('[SocketService] ❌ Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    _reconnectTimer?.cancel();

    final delay = Duration(
      seconds: reconnectDelay.inSeconds * _reconnectAttempts,
    );
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected.value && _userId != null && _token != null) {
        print(
          '[SocketService] 🔄 Attempting reconnection $_reconnectAttempts/$maxReconnectAttempts',
        );
        _createSocket();
      }
    });
  }

  void _cleanupSocket() {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket = null;
    _isConnected.value = false;
    _isConnecting.value = false;
    _eventListeners.clear(); // Fixed: Clear stored listeners
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (_socket?.connected == true) {
      _socket?.disconnect();
    }
    _cleanupSocket();
    print('[SocketService] 🔌 Disconnected manually');
  }

  Future<void> connect() async {
    if (_isConnected.value || _isConnecting.value) {
      print('[SocketService] ⚠️ Already connected or connecting');
      return;
    }

    if (_userId == null || _token == null) {
      print('[SocketService] ❌ Cannot connect: Missing credentials');
      throw StateError('Socket not initialized. Call initSocket first.');
    }

    if (_socket?.disconnected == true) {
      _socket?.connect();
      print('[SocketService] 🔄 Manually reconnecting...');
    } else {
      await _createSocket();
    }
  }

  bool _ensureConnection() {
    if (!_isConnected.value) {
      print('[SocketService] ⚠️ Socket not connected');
      return false;
    }
    return true;
  }

  // Fixed: Better type safety for callback storage
  void _addEventListenerToStorage(
    String event,
    void Function(dynamic) callback,
  ) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
  }

  // --- Core Socket Methods ---
  void joinRoom(String roomId, {required String userId}) {
    if (!_ensureConnection()) return;

    // Fixed: Better validation
    if (roomId.trim().isEmpty || userId.trim().isEmpty) {
      print('[SocketService] ⚠️ Invalid room or userId');
      return;
    }

    print('[SocketService] 🏠 Joining room: $roomId as $userId');
    _socket?.emit('join-room', {'roomId': roomId, 'userId': userId});
  }

  void leaveRoom(String roomId, {required String userId}) {
    if (!_ensureConnection()) return;

    if (roomId.trim().isEmpty || userId.trim().isEmpty) {
      print('[SocketService] ⚠️ Invalid room or userId for leaving');
      return;
    }

    print('[SocketService] 🚪 Leaving room: $roomId as $userId');
    _socket?.emit('leave-room', {'roomId': roomId, 'userId': userId});
  }

  // --- Enhanced Messaging ---
  void sendMessage(Map<String, dynamic> message) {
    if (!_ensureConnection()) return;

    final receiverId = message['receiverId'];
    final text = message['text'];

    // Fixed: Better validation
    if (receiverId == null ||
        receiverId.toString().trim().isEmpty ||
        text == null ||
        text.toString().trim().isEmpty) {
      print('[SocketService] ⚠️ Invalid message format');
      return;
    }

    final roomId = _generateRoomId(_userId!, receiverId.toString());
    final messageData = {
      'message': text,
      'to': receiverId,
      'roomId': roomId,
      'timestamp': DateTime.now().toIso8601String(), // Fixed: Added timestamp
      ...message,
    };

    print(
      '[SocketService] 📤 Sending message: $text to $receiverId in room: $roomId',
    );
    _socket?.emit('sendMessage', messageData);
  }

  void onNewMessage(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 📥 Message received: $data');
      try {
        Map<String, dynamic> messageData;
        if (data is Map<String, dynamic>) {
          messageData = data;
        } else if (data is Map) {
          messageData = Map<String, dynamic>.from(data);
        } else {
          print('[SocketService] ⚠️ Unexpected message format: $data');
          return;
        }
        callback(messageData);
      } catch (e) {
        print('[SocketService] ❌ Error processing message: $e');
      }
    };

    // Store listeners for reconnection
    _addEventListenerToStorage('receiveMessage', wrappedCallback);
    _addEventListenerToStorage('new-message', wrappedCallback);
    _addEventListenerToStorage('messageSent', wrappedCallback);

    _socket?.on('receiveMessage', wrappedCallback);
    _socket?.on('new-message', wrappedCallback);
    _socket?.on('messageSent', wrappedCallback);
  }

  // --- Enhanced Typing Events ---
  void sendTypingEvent(String toUserId) {
    if (!_ensureConnection() || toUserId.trim().isEmpty) return;

    final roomId = _generateRoomId(_userId!, toUserId);
    print(
      '[SocketService] ✍️ Sending typing event to: $toUserId in room: $roomId',
    );
    _socket?.emit('typing', {'to': toUserId, 'roomId': roomId});
  }

  void sendStoppedTypingEvent(String toUserId) {
    if (!_ensureConnection() || toUserId.trim().isEmpty) return;

    final roomId = _generateRoomId(_userId!, toUserId);
    print(
      '[SocketService] ✍️ Sending stopped typing event to: $toUserId in room: $roomId',
    );
    _socket?.emit('stop-typing', {'to': toUserId, 'roomId': roomId});
  }

  void onTyping(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] ✍️ Typing event received: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('userTyping', wrappedCallback);
    _addEventListenerToStorage('user-typing', wrappedCallback);

    _socket?.on('userTyping', wrappedCallback);
    _socket?.on('user-typing', wrappedCallback);
  }

  void onStoppedTyping(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] ✍️ Stopped typing event received: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('userStoppedTyping', wrappedCallback);
    _addEventListenerToStorage('user-stopped-typing', wrappedCallback);

    _socket?.on('userStoppedTyping', wrappedCallback);
    _socket?.on('user-stopped-typing', wrappedCallback);
  }

  // --- Online Users ---
  void onOnlineUsersUpdated(void Function(List<String>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 👥 Online users updated: $data');
      if (data is List) {
        callback(List<String>.from(data));
      }
    };

    _addEventListenerToStorage('getOnlineUsers', wrappedCallback);
    _socket?.on('getOnlineUsers', wrappedCallback);
  }

  // --- Message Status ---
  void markMessageAsSeen(String toUserId, String messageId) {
    if (!_ensureConnection() ||
        toUserId.trim().isEmpty ||
        messageId.trim().isEmpty)
      return;

    print(
      '[SocketService] 👁️ Marking message as seen: $messageId for user: $toUserId',
    );
    _socket?.emit('messageSeen', {'to': toUserId, 'messageId': messageId});
  }

  void onMessageSeen(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 👁️ Message seen event received: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('messageSeen', wrappedCallback);
    _socket?.on('messageSeen', wrappedCallback);
  }

  // --- Reactions ---
  void sendReaction(String messageId, String reaction) {
    if (!_ensureConnection() ||
        messageId.trim().isEmpty ||
        reaction.trim().isEmpty)
      return;

    print(
      '[SocketService] 😊 Sending reaction: $reaction for message: $messageId',
    );
    _socket?.emit('message-reaction', {
      'messageId': messageId,
      'reaction': reaction,
    });
  }

  void onReactionReceived(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 😊 Reaction received: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('message-reaction', wrappedCallback);
    _socket?.on('message-reaction', wrappedCallback);
  }

  // --- Call Events ---
  void emitCallRequest(String receiverId, String callerName, bool isVideoCall) {
    if (!_ensureConnection() ||
        receiverId.trim().isEmpty ||
        callerName.trim().isEmpty)
      return;

    print('[SocketService] 📞 Emitting call request to: $receiverId');
    _socket?.emit('call-request', {
      'receiverId': receiverId,
      'callerName': callerName,
      'isVideoCall': isVideoCall,
    });
  }

  void emitCallAccepted(String receiverId, bool isVideoCall) {
    if (!_ensureConnection() || receiverId.trim().isEmpty) return;

    print('[SocketService] ✅ Emitting call accepted to: $receiverId');
    _socket?.emit('call-accepted', {
      'receiverId': receiverId,
      'isVideoCall': isVideoCall,
    });
  }

  void emitCallRejected(String receiverId) {
    if (!_ensureConnection() || receiverId.trim().isEmpty) return;

    print('[SocketService] ❌ Emitting call rejected to: $receiverId');
    _socket?.emit('call-rejected', {'receiverId': receiverId});
  }

  void emitCallCancelled(String receiverId) {
    if (!_ensureConnection() || receiverId.trim().isEmpty) return;

    print('[SocketService] 🚫 Emitting call cancelled to: $receiverId');
    _socket?.emit('call-cancelled', {'receiverId': receiverId});
  }

  void emitCallEnded(String receiverId) {
    if (!_ensureConnection() || receiverId.trim().isEmpty) return;

    print('[SocketService] 📞 Emitting call ended to: $receiverId');
    _socket?.emit('call-ended', {'receiverId': receiverId});
  }

  // --- Call Event Listeners ---
  void onIncomingCall(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 📞 Incoming call: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('incoming-call', wrappedCallback);
    _socket?.on('incoming-call', wrappedCallback);
  }

  void onCallAccepted(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] ✅ Call accepted: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('call-accepted', wrappedCallback);
    _socket?.on('call-accepted', wrappedCallback);
  }

  void onCallRejected(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] ❌ Call rejected: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('call-rejected', wrappedCallback);
    _socket?.on('call-rejected', wrappedCallback);
  }

  void onCallCancelled(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 🚫 Call cancelled: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('call-cancelled', wrappedCallback);
    _socket?.on('call-cancelled', wrappedCallback);
  }

  void onCallEnded(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 📞 Call ended: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('call-ended', wrappedCallback);
    _socket?.on('call-ended', wrappedCallback);
  }

  // --- Room Events ---
  void onRoomJoined(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 🏠 Room joined: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('room-joined', wrappedCallback);
    _socket?.on('room-joined', wrappedCallback);
  }

  void onUserJoined(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 👤 User joined room: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('user-joined', wrappedCallback);
    _socket?.on('user-joined', wrappedCallback);
  }

  void onUserLeft(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 👤 User left room: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('user-left', wrappedCallback);
    _socket?.on('user-left', wrappedCallback);
  }

  // --- WebRTC Signaling ---
  void sendOffer(String receiverId, Map<String, dynamic> offer) {
    if (!_ensureConnection() || receiverId.trim().isEmpty) return;
    print('[SocketService] 📡 Sending WebRTC offer to: $receiverId');
    _socket?.emit('offer', {'offer': offer, 'to': receiverId});
  }

  void sendAnswer(String receiverId, Map<String, dynamic> answer) {
    if (!_ensureConnection() || receiverId.trim().isEmpty) return;
    print('[SocketService] 📡 Sending WebRTC answer to: $receiverId');
    _socket?.emit('answer', {'answer': answer, 'to': receiverId});
  }

  void sendIceCandidate(String receiverId, Map<String, dynamic> candidate) {
    if (!_ensureConnection() || receiverId.trim().isEmpty) return;
    print('[SocketService] 📡 Sending ICE candidate to: $receiverId');
    _socket?.emit('ice-candidate', {'candidate': candidate, 'to': receiverId});
  }

  void onOffer(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 📡 WebRTC offer received: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('offer', wrappedCallback);
    _socket?.on('offer', wrappedCallback);
  }

  void onAnswer(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 📡 WebRTC answer received: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('answer', wrappedCallback);
    _socket?.on('answer', wrappedCallback);
  }

  void onIceCandidate(void Function(Map<String, dynamic>) callback) {
    final wrappedCallback = (data) {
      print('[SocketService] 📡 ICE candidate received: $data');
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    };

    _addEventListenerToStorage('ice-candidate', wrappedCallback);
    _socket?.on('ice-candidate', wrappedCallback);
  }

  // --- Utility Methods ---
  // Fixed: Better room ID generation with validation
  String _generateRoomId(String userId1, String userId2) {
    if (userId1.trim().isEmpty || userId2.trim().isEmpty) {
      throw ArgumentError('User IDs cannot be empty');
    }

    final sorted = [userId1.trim(), userId2.trim()]..sort();
    return 'chat_${sorted.join("_")}';
  }

  void removeAllListeners() {
    _socket?.clearListeners();
    _eventListeners.clear();
  }

  void removeListener(String event) {
    _socket?.off(event);
    _eventListeners.remove(event);
  }

  Future<bool> ping() async {
    if (!_ensureConnection()) return false;

    final completer = Completer<bool>();
    final timer = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    _socket?.emit('ping');
    _socket?.once('pong', (_) {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.complete(true);
      }
    });

    return completer.future;
  }

  // Fixed: Better stream handling
  Stream<bool> get connectionStream => _isConnected.stream;
  Stream<String> get connectionStatusStream => _connectionStatus.stream;
}
