import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../services/socket_service.dart';

class CallController extends GetxController {
  // Observable variables - Fixed redundancy
  var isInCall = false.obs;
  var isVideoCall = false.obs;
  var isMuted = false.obs;
  var isVideoEnabled = true.obs;
  var isConnected = false.obs;
  var callDuration = 0.obs;
  var connectionStatus = 'Connecting...'.obs;

  // WebRTC variables
  webrtc.RTCPeerConnection? _peerConnection;
  webrtc.MediaStream? _localStream;
  webrtc.MediaStream? _remoteStream;
  webrtc.RTCVideoRenderer localRenderer = webrtc.RTCVideoRenderer();
  webrtc.RTCVideoRenderer remoteRenderer = webrtc.RTCVideoRenderer();

  // Call variables
  String? currentCallId;
  String? remoteUserId;
  bool isInitiator = false;

  // Socket service with null safety
  final SocketService socketService = Get.find<SocketService>();

  // Timer for call duration
  Timer? _callTimer;

  @override
  void onInit() {
    super.onInit();
    _initializeRenderers();
    _setupSocketListeners();
  }

  Future<void> _initializeRenderers() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
    } catch (e) {
      print('Error initializing renderers: $e');
      _showError('Failed to initialize video renderers');
    }
  }

  void _setupSocketListeners() {
    final socket = socketService.socket;

    // Fixed: Added null safety check
    if (socket == null) {
      print('Socket is null, cannot setup listeners');
      return;
    }

    socket.on('webrtc-offer', (data) => _handleOffer(data));
    socket.on('webrtc-answer', (data) => _handleAnswer(data));
    socket.on('webrtc-ice-candidate', (data) => _handleIceCandidate(data));
    socket.on('call-ended', (_) => endCall());
  }

  /// Main method to start a call
  Future<void> startCall(String userId, bool videoCall) async {
    try {
      // Validation
      if (userId.isEmpty) {
        _showError('Invalid user ID');
        return;
      }

      // Check permissions first
      if (!await _checkPermissions(videoCall)) {
        _showError('Permissions not granted');
        return;
      }

      // Set call state
      isInCall.value = true;
      isVideoCall.value = videoCall;
      remoteUserId = userId;
      isInitiator = true;
      connectionStatus.value = 'Connecting...';

      // Initialize WebRTC
      await _initializeWebRTC();

      // Get user media
      await _getUserMedia(videoCall);

      // Create offer
      await _createOffer();

      // Start call timer
      _startCallTimer();

      print('Call started successfully');
    } catch (e) {
      print('Error starting call: $e');
      _showError('Failed to start call: ${e.toString()}');
      await endCall(); // Fixed: Made async
    }
  }

  /// Initialize WebRTC peer connection
  Future<void> _initializeWebRTC() async {
    // Fixed: More comprehensive STUN/TURN servers
    final configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
            'stun:stun3.l.google.com:19302',
          ],
        },
      ],
      'iceCandidatePoolSize': 10,
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    try {
      _peerConnection = await webrtc.createPeerConnection(
        configuration,
        constraints,
      );

      // Handle ICE candidates
      _peerConnection?.onIceCandidate = (webrtc.RTCIceCandidate candidate) {
        final socket = socketService.socket;
        if (socket != null && remoteUserId != null) {
          socket.emit('webrtc-ice-candidate', {
            'to': remoteUserId,
            'candidate': candidate.toMap(),
          });
        }
      };

      // Handle remote stream
      _peerConnection?.onAddStream = (webrtc.MediaStream stream) {
        _remoteStream = stream;
        remoteRenderer.srcObject = stream;
        connectionStatus.value = 'Connected';
        isConnected.value = true;
      };

      // Handle connection state changes
      _peerConnection?.onConnectionState = (
        webrtc.RTCPeerConnectionState state,
      ) {
        switch (state) {
          case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            connectionStatus.value = 'Connected';
            isConnected.value = true;
            break;
          case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            connectionStatus.value = 'Disconnected';
            isConnected.value = false;
            break;
          case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            connectionStatus.value = 'Connection failed';
            endCall();
            break;
          case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            connectionStatus.value = 'Connecting...';
            break;
          default:
            break;
        }
      };

      // Fixed: Added ICE connection state handling
      _peerConnection?.onIceConnectionState = (
        webrtc.RTCIceConnectionState state,
      ) {
        print('ICE Connection State: $state');
        if (state == webrtc.RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _showError('Connection failed - please check your network');
        }
      };
    } catch (e) {
      print('Error initializing WebRTC: $e');
      throw Exception('Failed to initialize WebRTC: $e');
    }
  }

  /// Get user media (camera/microphone)
  Future<void> _getUserMedia(bool videoCall) async {
    try {
      final constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video':
            videoCall
                ? {
                  'mandatory': {
                    'minWidth': '640',
                    'minHeight': '480',
                    'minFrameRate': '30',
                  },
                  'facingMode': 'user',
                  'optional': [],
                }
                : false,
      };

      _localStream = await webrtc.navigator.mediaDevices.getUserMedia(
        constraints,
      );

      if (_localStream == null) {
        throw Exception('Failed to get user media');
      }

      localRenderer.srcObject = _localStream;

      // Add stream to peer connection
      if (_peerConnection != null) {
        _peerConnection!.addStream(_localStream!);
      }
    } catch (e) {
      print('Error getting user media: $e');
      throw Exception('Failed to access camera/microphone: $e');
    }
  }

  /// Create WebRTC offer
  Future<void> _createOffer() async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      webrtc.RTCSessionDescription description =
          await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(description);

      // Send offer through socket
      final socket = socketService.socket;
      if (socket != null && remoteUserId != null) {
        socket.emit('webrtc-offer', {
          'to': remoteUserId,
          'offer': description.toMap(),
        });
      } else {
        throw Exception('Socket or remote user ID not available');
      }
    } catch (e) {
      print('Error creating offer: $e');
      throw Exception('Failed to create offer: $e');
    }
  }

  /// Handle incoming WebRTC offer
  Future<void> _handleOffer(dynamic data) async {
    try {
      // Fixed: Better data validation
      if (data == null || data['offer'] == null || data['from'] == null) {
        print('Invalid offer data received');
        return;
      }

      if (!isInCall.value) {
        // This is an incoming call, initialize everything
        isInCall.value = true;
        // Fixed: Proper video call detection
        final offerData = data['offer'];
        isVideoCall.value = offerData['sdp']?.contains('video') ?? false;
        remoteUserId = data['from'];
        isInitiator = false;

        await _initializeWebRTC();
        await _getUserMedia(isVideoCall.value);
        _startCallTimer();
      }

      // Set remote description
      webrtc.RTCSessionDescription description = webrtc.RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );
      await _peerConnection!.setRemoteDescription(description);

      // Create answer
      webrtc.RTCSessionDescription answer =
          await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer through socket
      final socket = socketService.socket;
      if (socket != null && remoteUserId != null) {
        socket.emit('webrtc-answer', {
          'to': remoteUserId,
          'answer': answer.toMap(),
        });
      }
    } catch (e) {
      print('Error handling offer: $e');
      await endCall();
    }
  }

  /// Handle WebRTC answer
  Future<void> _handleAnswer(dynamic data) async {
    try {
      if (data == null || data['answer'] == null) {
        print('Invalid answer data received');
        return;
      }

      webrtc.RTCSessionDescription description = webrtc.RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      await _peerConnection!.setRemoteDescription(description);
    } catch (e) {
      print('Error handling answer: $e');
      await endCall();
    }
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(dynamic data) async {
    try {
      if (data == null || data['candidate'] == null) {
        print('Invalid ICE candidate data received');
        return;
      }

      webrtc.RTCIceCandidate candidate = webrtc.RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  /// Check required permissions
  Future<bool> _checkPermissions(bool videoCall) async {
    try {
      final permissionsToRequest = [
        Permission.microphone,
        if (videoCall) Permission.camera,
      ];

      Map<Permission, PermissionStatus> permissions =
          await permissionsToRequest.request();

      return permissions.values.every((status) => status.isGranted);
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  /// Start call timer
  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      callDuration.value++;
    });
  }

  /// Toggle mute - Fixed logic
  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = isMuted.value; // Enable if currently muted
      }
      isMuted.value = !isMuted.value;
    }
  }

  /// Toggle video - Fixed logic
  void toggleVideo() {
    if (_localStream != null && isVideoCall.value) {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = isVideoEnabled.value; // Enable if currently disabled
      }
      isVideoEnabled.value = !isVideoEnabled.value;
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_localStream != null && isVideoCall.value) {
      try {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          await webrtc.Helper.switchCamera(videoTracks.first);
        }
      } catch (e) {
        print('Error switching camera: $e');
        _showError('Failed to switch camera');
      }
    }
  }

  /// End call - Fixed to be async
  Future<void> endCall() async {
    try {
      // Stop call timer
      _callTimer?.cancel();
      _callTimer = null;

      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Stop local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        await _localStream!.dispose();
        _localStream = null;
      }

      // Stop remote stream
      if (_remoteStream != null) {
        await _remoteStream!.dispose();
        _remoteStream = null;
      }

      // Clear renderers
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      // Notify other user
      if (remoteUserId != null) {
        final socket = socketService.socket;
        socket?.emit('call-ended', {'to': remoteUserId});
      }

      // Reset state
      isInCall.value = false;
      isVideoCall.value = false;
      isMuted.value = false;
      isVideoEnabled.value = true;
      isConnected.value = false;
      callDuration.value = 0;
      connectionStatus.value = 'Disconnected';
      currentCallId = null;
      remoteUserId = null;
      isInitiator = false;

      print('Call ended successfully');
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  /// Get formatted call duration
  String getFormattedDuration() {
    final duration = callDuration.value;
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Show error message
  void _showError(String message) {
    Get.snackbar(
      'Call Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 3),
    );
  }

  // Fixed: Added proper disposal
  @override
  void onClose() {
    endCall();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.onClose();
  }
}
