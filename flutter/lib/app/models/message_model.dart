enum MessageStatus { sent, delivered, seen }

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? text;
  final String? image;
  final DateTime createdAt;
  MessageStatus status;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.text,
    this.image,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Parse status from json if available, fallback to sent
    MessageStatus parseStatus(String? statusString) {
      switch (statusString) {
        case 'delivered':
          return MessageStatus.delivered;
        case 'seen':
          return MessageStatus.seen;
        case 'sent':
        default:
          return MessageStatus.sent;
      }
    }

    return MessageModel(
      id: json['_id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      text: json['text'],
      image: json['image'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    String statusToString(MessageStatus status) {
      switch (status) {
        case MessageStatus.delivered:
          return 'delivered';
        case MessageStatus.seen:
          return 'seen';
        case MessageStatus.sent:
        default:
          return 'sent';
      }
    }

    return {
      '_id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'image': image,
      'createdAt': createdAt.toIso8601String(),
      'status': statusToString(status),
    };
  }
}
