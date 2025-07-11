import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../controllers/call_controller.dart';
import '../../services/socket_service.dart';

class CallScreen extends StatefulWidget {
  final String? userId;
  final String? receiverId; // Added receiverId parameter
  final bool isVideoCall;
  final bool isIncomingCall;

  const CallScreen({
    Key? key,
    this.userId,
    this.receiverId, // Added receiverId parameter
    this.isVideoCall = false,
    this.isIncomingCall = false,
    required String receiverName,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallController callController;
  late final SocketService socketService;

  @override
  void initState() {
    super.initState();
    callController = Get.find<CallController>();
    socketService = Get.find<SocketService>();

    if (!widget.isIncomingCall) {
      // Use receiverId if provided, otherwise fall back to userId
      final targetUserId = widget.receiverId ?? widget.userId;
      if (targetUserId != null) {
        // Start outgoing call
        WidgetsBinding.instance.addPostFrameCallback((_) {
          callController.startCall(targetUserId, widget.isVideoCall);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          return Stack(
            children: [
              // Remote video (full screen)
              if (callController.isVideoCall.value &&
                  callController.isConnected.value)
                Positioned.fill(
                  child: RTCVideoView(
                    callController.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),

              // Local video (picture-in-picture)
              if (callController.isVideoCall.value)
                Positioned(
                  top: 50,
                  right: 20,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: RTCVideoView(
                        callController.localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Call info overlay
              if (!callController.isVideoCall.value ||
                  !callController.isConnected.value)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // User avatar
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                          ),
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // User name - Use receiverId or userId
                        Text(
                          widget.receiverId ?? widget.userId ?? 'Unknown User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Call status
                        Text(
                          callController.connectionStatus.value,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Call duration
                        if (callController.isConnected.value)
                          Text(
                            callController.getFormattedDuration(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Control buttons
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    _buildControlButton(
                      icon:
                          callController.isMuted.value
                              ? Icons.mic_off
                              : Icons.mic,
                      onPressed: callController.toggleMute,
                      backgroundColor:
                          callController.isMuted.value
                              ? Colors.red
                              : Colors.white.withOpacity(0.2),
                    ),

                    // End call button
                    _buildControlButton(
                      icon: Icons.call_end,
                      onPressed: () async {
                        await callController.endCall();
                        Get.back();
                      },
                      backgroundColor: Colors.red,
                      size: 60,
                    ),

                    // Video toggle button (only for video calls)
                    if (callController.isVideoCall.value)
                      _buildControlButton(
                        icon:
                            callController.isVideoEnabled.value
                                ? Icons.videocam
                                : Icons.videocam_off,
                        onPressed: callController.toggleVideo,
                        backgroundColor:
                            callController.isVideoEnabled.value
                                ? Colors.white.withOpacity(0.2)
                                : Colors.red,
                      ),

                    // Camera switch button (only for video calls)
                    if (callController.isVideoCall.value)
                      _buildControlButton(
                        icon: Icons.switch_camera,
                        onPressed: callController.switchCamera,
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                  ],
                ),
              ),

              // Back button
              Positioned(
                top: 20,
                left: 20,
                child: IconButton(
                  onPressed: () async {
                    await callController.endCall();
                    Get.back();
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
