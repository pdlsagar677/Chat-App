class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? profilePic;
  final bool isAdmin;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isTyping;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.profilePic,
    this.isAdmin = false,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isTyping = false,
    this.isOnline = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      profilePic: json['profilePic'],
      isAdmin: json['isAdmin'] ?? false,
      lastMessage: json['lastMessage'],
      lastMessageTime:
          json['lastMessageTime'] != null
              ? DateTime.tryParse(json['lastMessageTime'].toString())
              : null,
      unreadCount: json['unreadCount'] ?? 0,
      isTyping: json['isTyping'] ?? false,
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'profilePic': profilePic,
      'isAdmin': isAdmin,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'isTyping': isTyping,
      'isOnline': isOnline,
    };
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? profilePic,
    bool? isAdmin,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isTyping,
    bool? isOnline,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      profilePic: profilePic ?? this.profilePic,
      isAdmin: isAdmin ?? this.isAdmin,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isTyping: isTyping ?? this.isTyping,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, email: $email, isOnline: $isOnline, unreadCount: $unreadCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
