import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/create_group_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  bool _isLoading = true;
  List _chats = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future _loadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _error = 'Не авторизован';
          _isLoading = false;
        });
        return;
      }

      final api = ApiService();
      final response = await api.getGroups(token);
      final isSuccess = response["success"];
      if (isSuccess == true) {
        final data = response["data"];

        if (data == null) {
          setState(() {
            _error = 'Данные пусты';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _chats = data;
          _isLoading = false;
        });
      } else {
        final message = response["message"] ?? 'Неизвестная ошибка';
        setState(() {
          _error = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onCreateGroupPressed() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );

    if (result == true) {
      _loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          await _loadChats();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ошибка: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _loadChats();
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              )
            : _chats.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Нет чатов',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  final name = chat['name'] ?? 'Без названия';
                  final lastMessage = chat['last_message']['content'] ?? 'Нет сообщений';
                  final avatarPath = chat['avatar_path'];
                  final groupId = chat['id'];
                  final lastMessageUsername = chat['last_message']['author_username'] ?? 'Профиль недоступен';

                  return ListTile(
                    leading: _buildAvatar(name, avatarPath),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Text("$lastMessageUsername: "),
                        Expanded(
                          child: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            groupId: groupId,
                            groupName: name,
                            groupAvatar: avatarPath,
                          ),
                        ),
                      );

                      if (result == true) {
                        _loadChats();
                      }
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreateGroupPressed,
        tooltip: 'Создать группу',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAvatar(String name, String? avatarPath) {
    const double size = 50;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage('http://45.132.255.102:8000/$avatarPath'),
      );
    }

    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _getColorForName(name);

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getColorForName(String name) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final index = name.length % colors.length;
    return colors[index];
  }
}
