import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersProfileScreen extends StatefulWidget {
  final int userId;
  const UsersProfileScreen({
    super.key,
    required this.userId
  });

  @override
  State<UsersProfileScreen> createState() => _UsersProfileScreen();
}

class _UsersProfileScreen extends State<UsersProfileScreen> {
  bool _isLoading = true;
  String? _error;
  
  String _username = '';
  String _name = '';
  String _lastName = '';
  String? _avatarPath;
  String? _description;
  final String _baseURL = "http://45.132.255.102:8000/";



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
      final response = await api.getUserDetails(token, widget.userId);

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
          _name = data["name"] ?? '';
          _lastName = data["last_name"] ?? '';
          _description = data["description"];
          _avatarPath = data["avatar_path"];
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Профиль'),
        ),
        body: Center(
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 25),
          Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 15),
              Text(
                "$_name $_lastName",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                "Id: ${widget.userId}",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                  const Divider(),
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
      ),
      
    );
  }

  
  Widget _buildAvatarSection() {
    final bool hasAvatar = _avatarPath != null && _avatarPath!.isNotEmpty;

    return GestureDetector(
      onTap: hasAvatar ? _showFullAvatar : null,
      child: CircleAvatar(
        radius: 50,
        backgroundImage: hasAvatar
            ? NetworkImage("$_baseURL$_avatarPath") as ImageProvider
            : null,
        child: hasAvatar
            ? null
            : const Icon(Icons.group, size: 50, color: Colors.grey),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon, 
    String value, 
    String label, 
  ) {
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
        
      ],
    );
  }

  void _showFullAvatar() {    
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    "$_baseURL$_avatarPath",
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.white, size: 50);
                    },
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                  tooltip: "Закрыть",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
}