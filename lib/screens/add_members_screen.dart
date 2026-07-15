import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';

class AddMembersScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const AddMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _foundUsers = [];
  final Set<int> _selectedUserIds = {};
  bool _isSearching = false;
  bool _isAdding = false;
  String? _error;
  Timer? _debounce;
  final String _baseURL = "http://45.132.255.102:8000/";

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _foundUsers.clear();
        _error = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _error = 'Не авторизован';
          _isSearching = false;
        });
        return;
      }

      final api = ApiService();
      final response = await api.searchUsers(token, query);

      if (response["success"] == true) {
        final data = response["data"] ?? [];
        setState(() {
          _foundUsers = List<Map<String, dynamic>>.from(data);
          _isSearching = false;
        });
      } else {
        setState(() {
          _error = response["message"] ?? 'Ошибка поиска';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного пользователя')),
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _isAdding = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Не авторизован')));
        return;
      }

      final api = ApiService();
      final response = await api.addGroupMembers(
        token,
        widget.groupId,
        _selectedUserIds.toList(),
      );

      setState(() {
        _isAdding = false;
      });

      if (response["success"] == true) {
        final message = response["message"] ?? 'Участники добавлены';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (mounted) {
          Navigator.pop(
            context,
            true,
          ); // Возвращаем true, чтобы обновить список
        }
      } else {
        final message = response["message"] ?? 'Ошибка добавления';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAdding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Добавить в "${widget.groupName}"')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по нику...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _foundUsers = [];
                            _error = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                // Отменяем предыдущий таймер
                _debounce?.cancel();

                final query = value.trim();

                if (query.isEmpty) {
                  setState(() {
                    _foundUsers = [];
                    _error = null;
                  });
                  return;
                }

                // Запускаем новый таймер на 500мс
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  _searchUsers();
                });
              },
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Ошибка: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _searchUsers,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : _foundUsers.isEmpty
                ? const Center(
                    child: Text(
                      'Введите ник для поиска',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _foundUsers.length,
                    itemBuilder: (context, index) {
                      final user = _foundUsers[index];
                      final userId = user['id'];
                      final username = user['username'] ?? 'Без ника';
                      final name = user['name'] ?? '';
                      final lastName = user['last_name'] ?? '';
                      final avatarPath = user['avatar_path'];
                      final fullName = '$name $lastName'.trim();

                      return CheckboxListTile(
                        value: _selectedUserIds.contains(userId),
                        onChanged: (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedUserIds.add(userId);
                            } else {
                              _selectedUserIds.remove(userId);
                            }
                          });
                        },
                        title: Text(
                          fullName.isNotEmpty ? fullName : username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$username'),
                        secondary: _buildAvatar(
                          fullName.isNotEmpty ? fullName : username,
                          avatarPath,
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _isAdding
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: _selectedUserIds.isEmpty
                      ? null
                      : _addSelectedMembers,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _selectedUserIds.isEmpty
                        ? 'Добавить участников'
                        : 'Добавить (${_selectedUserIds.length})',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar(String name, String? avatarPath) {
    const double size = 40;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage('$_baseURL$avatarPath'),
      );
    }

    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
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
    final color = colors[index];

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
