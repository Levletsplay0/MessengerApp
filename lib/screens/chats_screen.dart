import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  bool _isLoading = true;
  List<dynamic> _chats = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
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
      List data = response["data"];

      setState(() {
        _chats = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чаты'), actions: [IconButton(onPressed: _logout, icon: Icon(Icons.logout))],),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ошибка: $_error'),
                      const SizedBox(height: 16,),
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
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          final name = chat['name'] ?? 'Без названия';
                          final description = chat['description'] ?? 'Без описания';
                          final avatarPath = chat['avatar_path'];
                          return ListTile(
                            leading: _buildAvatar(name, avatarPath),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            subtitle: Text(description),
                            onTap: () {},
                          );
                        },
                      ),
                    )
                  ],
                ),
    );
  }

  Widget _buildAvatar(String name, String? avatarPath) {
    const double size = 50;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(
          'http://45.132.255.102:8000/$avatarPath',
        ),
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