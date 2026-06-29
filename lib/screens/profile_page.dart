import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String? _error;
  
  String _username = '';
  String _email = '';
  String? _avatarPath;
  String? _description;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
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
      final response = await api.getMe(token);

      final isSuccess = response["success"];
      if (isSuccess == true) {
        final data = response["data"];
        
        if (data == null) {
          setState(() {
            _error = 'Данные профиля пусты';
            _isLoading = false;
          });
          return;
        }
        
        setState(() {
          _username = data["username"] ?? '';
          _email = data["email"] ?? '';
          _avatarPath = data["avatar_path"];
          _description = data["description"];
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
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
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
                _loadProfile();
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        const SizedBox(height: 25),
        Column(
          children: [
            _buildAvatar(),
            const SizedBox(height: 15),
            Text(
              _username,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8, left: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.image),
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  label: const Text(
                    "Изменить фото",
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  label: const Text(
                    "Удалить фото",
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.person_outline, _username, 'Имя пользователя'),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.email_outlined, _email, 'Почта'),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.description_outlined,
                  _description ?? 'Не указано',
                  'Описание',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue, width: 2),
          color: Colors.transparent,
        ),
        child: CircleAvatar(
          radius: 50,
          backgroundImage: NetworkImage(
            'http://45.132.255.102:8000/$_avatarPath',
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
        color: Colors.transparent,
      ),
      child: const CircleAvatar(
        radius: 50,
        backgroundColor: Colors.transparent,
        child: Icon(Icons.person_rounded, size: 50),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(onPressed: (){}, child: Text("Изменить"))
      ],
    );
  }
}