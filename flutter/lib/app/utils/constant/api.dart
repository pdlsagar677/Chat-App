import 'package:flutter_dotenv/flutter_dotenv.dart';

class API {
  static final String baseUrl =
      dotenv.env['BASE_URL'] ?? 'http://localhost:5001';
  static final String socketUrl =
      dotenv.env['SOCKET_URL'] ?? 'http://localhost:5001';
}
