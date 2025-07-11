// Service for API calls
import 'dart:convert';

import 'package:chat_app/app/models/message_model.dart';
import 'package:http/http.dart' as http;

class MessageService {
  final String baseUrl;
  final String authToken;

  MessageService({required this.baseUrl, required this.authToken});

  Future<List<MessageModel>> fetchMessages(String chatUserId) async {
    final url = Uri.parse('$baseUrl/api/messages/$chatUserId');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => MessageModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<MessageModel?> sendMessage(String receiverId, String text) async {
    final url = Uri.parse('$baseUrl/api/messages/send/$receiverId');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: json.encode({'text': text}),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return MessageModel.fromJson(data);
    } else {
      print('Send message failed: ${response.body}');
      return null;
    }
  }
}
