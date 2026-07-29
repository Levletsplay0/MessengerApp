import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  String? _wsUrl;
  Timer? _reconnectTimer;
  
  bool _isIntentionalDisconnect = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  void connect(String baseUrl, int groupId, String token) {
    _isIntentionalDisconnect = false;
    _reconnectAttempts = 0;
    
    _wsUrl = 'ws://${baseUrl.replaceFirst('http://', '').replaceFirst('https://', '')}/ws/$groupId?token=$token';
    _connect();
  }

  void _connect() {
    if (_wsUrl == null || _isIntentionalDisconnect) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl!));
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String);
            _messageController.add(message);
          } catch (e) {
            print('Ошибка парсинга WS сообщения: $e');
          }
        },
        onError: (error) {
          print('WebSocket ошибка: $error');
          _isConnected = false;
          _attemptReconnect(error);
        },
        onDone: () {
          print('WebSocket закрыт');
          _isConnected = false;
          _attemptReconnect(null);
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('Ошибка подключения WS: $e');
      _isConnected = false;
      _attemptReconnect(e);
    }
  }

  void _attemptReconnect(dynamic error) {
    if (_isIntentionalDisconnect) {
      print('✅ Переподключение отменено (намеренное отключение)');
      return;
    }

    if (error != null && error.toString().contains('was not upgraded to websocket')) {
      print('❌ Критическая ошибка: Группа удалена или доступ запрещен. Переподключение остановлено навсегда.');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Превышено макс. кол-во попыток переподключения');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    print("Попытка переподключения $_reconnectAttempts через ${delay.inSeconds}с...");

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isIntentionalDisconnect) {
        _connect();
      }
    });
  }

  void sendTextMessage(String content) {
    if (_channel == null || !_isConnected) {
      print('WebSocket не подключен');
      return;
    }
    final message = jsonEncode({"action": "send_message", "content": content});
    _channel!.sink.add(message);
  }

  void editMessage(int messageId, String newContent) {
    if (_channel == null || !_isConnected) return;
    final message = jsonEncode({
      "action": "edit_message",
      "message_id": messageId,
      "content": newContent,
    });
    _channel!.sink.add(message);
  }

  void deleteMessage(int messageId) {
    if (_channel == null || !_isConnected) return;
    final message = jsonEncode({
      "action": "delete_message",
      "message_id": messageId,
    });
    _channel!.sink.add(message);
  }

  void disconnect() {
    print('🛑 Вызов disconnect(): намеренное отключение WebSocket');
    _isIntentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }

  void sendTyping() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({"action": "typing"}));
    }
  }

  void sendStopTyping() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({"action": "stop_typing"}));
    }
  }
}