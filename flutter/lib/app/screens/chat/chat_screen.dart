import 'dart:convert';

import 'package:chat_app/app/controllers/call_controller.dart';
import 'package:chat_app/app/controllers/message_controller.dart';
import 'package:chat_app/app/controllers/theme_controller.dart';
import 'package:chat_app/app/screens/call/call_screen.dart';
import 'package:chat_app/app/themes/theme_selector_sheet.dart';
import 'package:chat_app/app/widgets/emoji_input.dart';
import 'package:chat_app/app/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final messageController = Get.find<MessageController>();
  final callController = Get.put(CallController());
  final themeController = Get.find<ThemeController>();
  final textController = TextEditingController();
  final focusNode = FocusNode();
  final scrollController = ScrollController();
  final storage = GetStorage();
  final ImagePicker imagePicker = ImagePicker();

  late String receiverId;
  late String receiverName;
  late AnimationController _scrollAnimationController;

  bool showEmojiPicker = false;
  Map<String, dynamic>? replyingTo;
  bool _autoScrollEnabled = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scrollAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize with widget parameters and save to storage
    receiverId = widget.receiverId;
    receiverName = widget.receiverName;

    _initializeChat();
    _setupTextFieldListeners();
    _setupMessageListeners();
    _setupCallListeners();
  }

  void _initializeChat() {
    try {
      // Use widget parameters or fallback to arguments/storage
      final args = Get.arguments;
      receiverId =
          widget.receiverId.isNotEmpty
              ? widget.receiverId
              : args?['userId'] ?? storage.read('chat_userId') ?? '';
      receiverName =
          widget.receiverName.isNotEmpty
              ? widget.receiverName
              : args?['userName'] ?? storage.read('chat_userName') ?? 'Unknown';

      if (receiverId.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed) {
            Get.back();
          }
        });
        return;
      }

      // Save to storage for persistence
      storage.write('chat_userId', receiverId);
      storage.write('chat_userName', receiverName);

      print(
        '[ChatScreen] Initializing chat with userId: $receiverId, userName: $receiverName',
      );

      // Initialize conversation with proper error handling
      Future.microtask(() async {
        try {
          messageController.startConversation(receiverId);
          messageController.markMessagesAsSeen(receiverId);
        } catch (e) {
          debugPrint('Error initializing chat: $e');
          if (!_isDisposed) {
            _showSnackbar('Error', 'Failed to initialize chat');
          }
        }
      });
    } catch (e) {
      debugPrint('Error in _initializeChat: $e');
      if (!_isDisposed) {
        Get.back();
      }
    }
  }

  void _setupTextFieldListeners() {
    textController.addListener(() {
      if (_isDisposed) return;

      final text = textController.text.trim();
      try {
        if (text.isNotEmpty) {
          messageController.sendTypingEvent(receiverId);
        } else {
          messageController.sendStoppedTypingEvent(receiverId);
        }
      } catch (e) {
        debugPrint('Error in typing event: $e');
      }
    });

    focusNode.addListener(() {
      if (_isDisposed) return;

      if (focusNode.hasFocus) {
        if (mounted) {
          setState(() => showEmojiPicker = false);
        }
      }
    });
  }

  void _setupMessageListeners() {
    // Listen for new messages and auto-scroll
    ever(messageController.chatMessages, (messages) {
      if (_isDisposed || !mounted) return;

      if (_autoScrollEnabled && messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed) {
            _scrollToBottom();
          }
        });
      }
    });

    // Listen for loading state changes
    ever(messageController.isLoading, (isLoading) {
      if (_isDisposed || !mounted) return;

      if (!isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed) {
            _scrollToBottom();
          }
        });
      }
    });

    // Auto-scroll when keyboard appears
    focusNode.addListener(() {
      if (_isDisposed || !mounted) return;

      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_isDisposed) {
            _scrollToBottom();
          }
        });
      }
    });
  }

  void _setupCallListeners() {
    try {
      final socketService = messageController.socketService;

      socketService.onIncomingCall((data) {
        if (_isDisposed || !mounted) return;

        try {
          _showIncomingCallDialog(data);
        } catch (e) {
          debugPrint('Error handling incoming call: $e');
        }
      });

      socketService.onCallEnded((data) {
        if (_isDisposed || !mounted) return;

        try {
          if (callController.isInCall.value) {
            callController.endCall();
            if (Get.isRegistered<CallController>()) {
              Get.back();
            }
          }
        } catch (e) {
          debugPrint('Error handling call ended: $e');
        }
      });

      socketService.onCallAccepted((data) {
        if (_isDisposed || !mounted) return;

        try {
          if (Get.isDialogOpen ?? false) {
            Get.back(); // Close calling dialog
            _startCall(data['isVideoCall'] ?? false);
          }
        } catch (e) {
          debugPrint('Error handling call accepted: $e');
        }
      });

      socketService.onCallRejected((data) {
        if (_isDisposed || !mounted) return;

        try {
          if (Get.isDialogOpen ?? false) {
            Get.back();
            _showSnackbar('Call Rejected', 'The user declined your call');
          }
        } catch (e) {
          debugPrint('Error handling call rejected: $e');
        }
      });
    } catch (e) {
      debugPrint('Error in _setupCallListeners: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isDisposed) {
      try {
        messageController.markMessagesAsSeen(receiverId);
      } catch (e) {
        debugPrint('Error marking messages as seen: $e');
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_isDisposed || !scrollController.hasClients) return;

    try {
      if (animated) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    } catch (e) {
      debugPrint('Error scrolling to bottom: $e');
    }
  }

  void _showSnackbar(String title, String message) {
    if (_isDisposed || !mounted) return;

    try {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Error showing snackbar: $e');
    }
  }

  // --- Pull to Refresh ---
  Future<void> _handleRefresh() async {
    if (_isDisposed) return;

    try {
      await messageController.fetchMessages(receiverId);
      await messageController.socketService.connect();
    } catch (e) {
      debugPrint('Error refreshing: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to refresh');
      }
    }
  }

  // --- Message Handling ---
  Future<void> handleSend() async {
    if (_isDisposed) return;

    final text = textController.text.trim();
    if (text.isEmpty) return;

    try {
      final success = await messageController.sendMessage(
        receiverId,
        text,
        replyToMessageId: replyingTo?['id'] ?? replyingTo?['_id'],
      );

      if (!_isDisposed && mounted) {
        if (success) {
          textController.clear();
          setState(() => replyingTo = null);
          focusNode.requestFocus();
          _scrollToBottom();
        } else {
          _showSnackbar('Error', 'Failed to send message');
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to send message');
      }
    }
  }

  // --- Enhanced File Handling ---
  Future<void> _showFilePickerOptions() async {
    if (_isDisposed || !mounted) return;

    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder:
            (context) => Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library,
                      color: Colors.blue,
                    ),
                    title: const Text('Photo Library'),
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.green),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.attach_file,
                      color: Colors.orange,
                    ),
                    title: const Text('Document'),
                    onTap: () => Navigator.pop(context, 'document'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cancel, color: Colors.red),
                    title: const Text('Cancel'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
      );

      if (result != null && !_isDisposed) {
        await _handleFileSelection(result);
      }
    } catch (e) {
      debugPrint('Error showing file picker options: $e');
    }
  }

  Future<void> _handleFileSelection(String type) async {
    if (_isDisposed) return;

    try {
      switch (type) {
        case 'gallery':
          await _pickImageFromGallery();
          break;
        case 'camera':
          await _pickImageFromCamera();
          break;
        case 'document':
          await _pickDocument();
          break;
      }
    } catch (e) {
      debugPrint('Error handling file selection: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to pick file: $e');
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isDisposed) return;

    try {
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && !_isDisposed) {
        await _sendImageFile(image);
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to pick image');
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (_isDisposed) return;

    try {
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && !_isDisposed) {
        await _sendImageFile(image);
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to take photo');
      }
    }
  }

  Future<void> _sendImageFile(XFile image) async {
    if (_isDisposed) return;

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = path.basename(image.path);

      final success = await messageController.sendMessage(
        receiverId,
        'Photo',
        base64Image: base64Image,
      );

      if (!_isDisposed && mounted) {
        if (success) {
          _scrollToBottom();
        } else {
          _showSnackbar('Error', 'Failed to send image');
        }
      }
    } catch (e) {
      debugPrint('Error sending image file: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to process image: $e');
      }
    }
  }

  Future<void> _pickDocument() async {
    if (_isDisposed) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty && !_isDisposed) {
        final file = result.files.first;

        if (file.bytes == null) {
          _showSnackbar('Error', 'Could not read file data');
          return;
        }

        // Check file size (limit to 10MB)
        if (file.size > 10 * 1024 * 1024) {
          _showSnackbar('Error', 'File too large (max 10MB)');
          return;
        }

        final base64File = base64Encode(file.bytes!);
        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';

        final success = await messageController.sendFile(
          receiverId,
          base64File,
          file.name,
          mimeType,
          text: 'Sent a file: ${file.name}',
        );

        if (!_isDisposed && mounted) {
          if (success) {
            _scrollToBottom();
          } else {
            _showSnackbar('Error', 'Failed to send file');
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to process file: $e');
      }
    }
  }

  // --- Reaction Handling ---
  void handleReaction(String messageId, String emoji) {
    if (_isDisposed) return;

    try {
      messageController.sendReaction(messageId, emoji);
    } catch (e) {
      debugPrint('Error sending reaction: $e');
    }
  }

  // --- Call Functions ---
  void _initiateCall(bool isVideoCall) async {
    if (_isDisposed) return;

    try {
      _showCallingDialog(isVideoCall);

      messageController.socketService.emitCallRequest(
        receiverId,
        storage.read('user_name') ?? 'Unknown',
        isVideoCall,
      );

      // Auto-cancel after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (!_isDisposed && (Get.isDialogOpen ?? false)) {
          Get.back();
          _cancelCall();
        }
      });
    } catch (e) {
      debugPrint('Error initiating call: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to initiate call');
      }
    }
  }

  void _showCallingDialog(bool isVideoCall) {
    if (_isDisposed || !mounted) return;

    try {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text('${isVideoCall ? "Video" : "Voice"} Calling...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  receiverName.isNotEmpty ? receiverName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                receiverName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Calling...', style: TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                _cancelCall();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      debugPrint('Error showing calling dialog: $e');
    }
  }

  void _showIncomingCallDialog(Map<String, dynamic> callData) {
    if (_isDisposed || !mounted) return;

    try {
      final callerName = callData['callerName'] ?? 'Unknown';
      final isVideoCall = callData['isVideoCall'] ?? false;

      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text('${isVideoCall ? "Video" : "Voice"} Call'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green.shade100,
                child: Text(
                  callerName.isNotEmpty ? callerName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                callerName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Incoming ${isVideoCall ? "video" : "voice"} call...',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                _rejectCall();
              },
              child: const Text('Decline', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                _acceptCall(isVideoCall);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Accept',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      debugPrint('Error showing incoming call dialog: $e');
    }
  }

  void _acceptCall(bool isVideoCall) {
    if (_isDisposed) return;

    try {
      messageController.socketService.emitCallAccepted(receiverId, isVideoCall);
      _startCall(isVideoCall);
    } catch (e) {
      debugPrint('Error accepting call: $e');
    }
  }

  void _rejectCall() {
    if (_isDisposed) return;

    try {
      messageController.socketService.emitCallRejected(receiverId);
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  void _cancelCall() {
    if (_isDisposed) return;

    try {
      messageController.socketService.emitCallCancelled(receiverId);
    } catch (e) {
      debugPrint('Error cancelling call: $e');
    }
  }

  void _startCall(bool isVideoCall) {
    if (_isDisposed) return;

    try {
      callController.startCall(receiverId, isVideoCall);
      Get.to(
        () => CallScreen(
          receiverId: receiverId,
          receiverName: receiverName, // ✅ Now supported
          isVideoCall: isVideoCall,
        ),
      );
    } catch (e) {
      debugPrint('Error starting call: $e');
      if (!_isDisposed) {
        _showSnackbar('Error', 'Failed to start call');
      }
    }
  }

  // --- Message Actions ---
  void _showMessageActions(Map<String, dynamic> message) {
    if (_isDisposed || !mounted) return;

    try {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder:
            (context) => Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.reply, color: Colors.blue),
                    title: const Text('Reply'),
                    onTap: () {
                      Navigator.pop(context);
                      if (mounted) {
                        setState(() => replyingTo = message);
                        focusNode.requestFocus();
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy, color: Colors.orange),
                    title: const Text('Copy'),
                    onTap: () {
                      Navigator.pop(context);
                      _copyMessage(message['text'] ?? '');
                    },
                  ),
                  if (message['senderId'] == storage.read('user_id'))
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Delete'),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMessage(message['id'] ?? message['_id']);
                      },
                    ),
                ],
              ),
            ),
      );
    } catch (e) {
      debugPrint('Error showing message actions: $e');
    }
  }

  void _copyMessage(String text) {
    if (_isDisposed) return;

    try {
      Clipboard.setData(ClipboardData(text: text));
      _showSnackbar('Copied', 'Message copied to clipboard');
    } catch (e) {
      debugPrint('Error copying message: $e');
      _showSnackbar('Error', 'Failed to copy message');
    }
  }

  void _deleteMessage(String messageId) {
    if (_isDisposed) return;

    try {
      messageController.deleteMessage(messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      _showSnackbar('Error', 'Failed to delete message');
    }
  }

  void _clearChat() {
    if (_isDisposed || !mounted) return;

    try {
      Get.dialog(
        AlertDialog(
          title: const Text('Clear Chat'),
          content: const Text('Are you sure you want to clear all messages?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                try {
                  messageController.clearChat(receiverId);
                  _showSnackbar(
                    'Chat Cleared',
                    'All messages have been deleted',
                  );
                } catch (e) {
                  debugPrint('Error clearing chat: $e');
                  _showSnackbar('Error', 'Failed to clear chat');
                }
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing clear chat dialog: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _scrollAnimationController.dispose();
    textController.dispose();
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Obx(() {
      final currentTheme = themeController.currentTheme.value;

      return Scaffold(
        backgroundColor: currentTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: currentTheme.appBarTheme.backgroundColor,
          foregroundColor: currentTheme.appBarTheme.foregroundColor,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: currentTheme.appBarTheme.foregroundColor,
            ),
            onPressed: () => Get.back(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                receiverName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: currentTheme.appBarTheme.foregroundColor,
                ),
              ),
              Obx(() {
                final isTyping = messageController.isUserTyping.value;
                final isOnline = messageController.isUserOnline.value;
                final isConnected = messageController.socketService.isConnected;

                Color statusColor;
                String statusText;

                if (!isConnected) {
                  statusColor = Colors.orange;
                  statusText = 'Connecting...';
                } else if (isTyping) {
                  statusColor = Colors.green;
                  statusText = 'Typing...';
                } else if (isOnline) {
                  statusColor = Colors.green;
                  statusText = 'Online';
                } else {
                  statusColor = Colors.grey;
                  statusText = 'Last seen recently';
                }

                return Text(
                  statusText,
                  style: TextStyle(fontSize: 12, color: statusColor),
                );
              }),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.videocam,
                color: currentTheme.appBarTheme.foregroundColor,
              ),
              onPressed: () => _initiateCall(true),
            ),
            IconButton(
              icon: Icon(
                Icons.call,
                color: currentTheme.appBarTheme.foregroundColor,
              ),
              onPressed: () => _initiateCall(false),
            ),
            IconButton(
              icon: Icon(
                Icons.palette,
                color: currentTheme.appBarTheme.foregroundColor,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (_) => showThemeSelectorSheet(),
                );
              },
            ),
            PopupMenuButton(
              icon: Icon(
                Icons.more_vert,
                color: currentTheme.appBarTheme.foregroundColor,
              ),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Clear Chat'),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'clear') {
                  _clearChat();
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Connection Status Indicator
            Obx(() {
              final isConnected = messageController.socketService.isConnected;
              if (!isConnected) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange,
                  child: const Text(
                    'Connecting to chat server...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Reply Preview
            if (replyingTo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 40,
                      color: currentTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to',
                            style: TextStyle(
                              fontSize: 12,
                              color: currentTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replyingTo!['text'] ?? 'Message',
                            style: TextStyle(
                              fontSize: 14,
                              color: currentTheme.textTheme.bodyMedium?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: currentTheme.iconTheme.color,
                      ),
                      onPressed: () {
                        if (mounted) {
                          setState(() => replyingTo = null);
                        }
                      },
                    ),
                  ],
                ),
              ),

            // Messages List with Pull to Refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: Obx(() {
                  if (messageController.isLoading.value &&
                      messageController.chatMessages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (messageController.chatMessages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: currentTheme.hintColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: currentTheme.hintColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation with $receiverName',
                            style: TextStyle(
                              fontSize: 14,
                              color: currentTheme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (scrollInfo is ScrollEndNotification) {
                        final pixels = scrollInfo.metrics.pixels;
                        final maxScroll = scrollInfo.metrics.maxScrollExtent;
                        _autoScrollEnabled = pixels >= maxScroll - 100;
                      }
                      return true;
                    },
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: messageController.chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = messageController.chatMessages[index];
                        return GestureDetector(
                          onLongPress: () => _showMessageActions(message),
                          child: MessageBubble(
                            message: message,
                            isMe:
                                message['senderId'] == storage.read('user_id'),
                            onReaction:
                                (emoji) => handleReaction(
                                  message['id'] ?? message['_id'],
                                  emoji,
                                ),
                            themeData: currentTheme,
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),

            // Emoji Picker
            if (showEmojiPicker)
              SizedBox(
                height: 250,
                child: EmojiInput(
                  onEmojiSelected: (emoji) {
                    if (!_isDisposed && mounted) {
                      textController.text += emoji;
                      textController.selection = TextSelection.fromPosition(
                        TextPosition(offset: textController.text.length),
                      );
                    }
                  },
                ),
              ),

            // Input Area
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentTheme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: currentTheme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file,
                      color: currentTheme.iconTheme.color,
                    ),
                    onPressed: _showFilePickerOptions,
                  ),
                  IconButton(
                    icon: Icon(
                      showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                      color: currentTheme.iconTheme.color,
                    ),
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          showEmojiPicker = !showEmojiPicker;
                          if (showEmojiPicker) {
                            focusNode.unfocus();
                          } else {
                            focusNode.requestFocus();
                          }
                        });
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(
                        color: currentTheme.textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: currentTheme.hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: currentTheme.cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: currentTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: currentTheme.colorScheme.onPrimary,
                      ),
                      onPressed: handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
