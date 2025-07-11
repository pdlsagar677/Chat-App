import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final Function(String)? onReaction;
  final ThemeData? themeData;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.onReaction,
    this.themeData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = themeData ?? Theme.of(context);
    final text = message['text'] ?? '';
    final timestamp = message['timestamp'] ?? message['createdAt'];
    final status = message['status'] ?? 'sent';
    final reaction = message['reaction'];
    final base64Image = message['image'];
    final fileName = message['fileName'];
    final mimeType = message['mimeType'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text(
                'U',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? theme.primaryColor : theme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image content
                  if (base64Image != null && base64Image.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.memory(
                        base64Decode(base64Image),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // File content
                  if (fileName != null && fileName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(mimeType),
                            color:
                                isMe ? Colors.white70 : theme.iconTheme.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              style: TextStyle(
                                color:
                                    isMe
                                        ? Colors.white
                                        : theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Text content
                  if (text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        text,
                        style: TextStyle(
                          color:
                              isMe
                                  ? Colors.white
                                  : theme.textTheme.bodyMedium?.color,
                          fontSize: 16,
                        ),
                      ),
                    ),

                  // Timestamp and status
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            color:
                                isMe
                                    ? Colors.white70
                                    : theme.textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _getStatusIcon(status),
                            size: 16,
                            color: Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Reaction
                  if (reaction != null)
                    Positioned(
                      bottom: -8,
                      right: isMe ? 8 : null,
                      left: isMe ? null : 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          reaction,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor,
              child: const Text(
                'M',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;

    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('document') || mimeType.contains('word')) {
      return Icons.description;
    }
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    }

    return Icons.insert_drive_file;
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return Icons.access_time;
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'seen':
        return Icons.done_all;
      default:
        return Icons.check;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime dateTime;

      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return DateFormat('MMM dd, HH:mm').format(dateTime);
      } else {
        return DateFormat('HH:mm').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }
}
