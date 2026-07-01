import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/edit_description_page.dart';
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
  String _name = '';
  String _lastName = '';
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
          _name = data["name"] ?? '';
          _lastName = data["last_name"] ?? '';
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

  Future<void> _deleteAvatar() async {
    try{
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      setState(() {
        _isLoading = true;
      });

      final api = ApiService();
      final response = await api.deleteAvatar(token!);
      

      final isSuccess = response["success"];
      if (isSuccess == true) {
        final message = response["message"];
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$message"),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.greenAccent,
            ),
        );
        _loadProfile();
      } else {
          final message = response["message"] ?? 'Неизвестная ошибка';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$message"),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
    }catch (e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$e"),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
    
  }

  Future<void> _pickAndUploadImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.first;
      
      String? filePath = platformFile.path;
      
      if (filePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('На веб-платформах требуется дополнительная обработка')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final api = ApiService();
      final response = await api.changeAvatar(token, File(filePath));

      final isSuccess = response["success"];
      
      if (isSuccess == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response["message"] ?? 'Аватар обновлен'),
              backgroundColor: Colors.teal,
            ),
          );
        }
        await _loadProfile();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response["message"] ?? 'Ошибка'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateDescription(String description) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || !mounted) return;

      final api = ApiService();
      final response = await api.updateDescription(token, description);

      if (!mounted) return;

      if (response["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response["message"] ?? 'Описание обновлено'),
            backgroundColor: Colors.greenAccent,
          ),
        );
        await _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response["message"] ?? 'Неизвестная ошибка'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ошибка: $e"),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
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
              "$_name $_lastName",
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
                  onPressed: _pickAndUploadImage,
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
                  onPressed: _deleteAvatar,
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
                const Divider(),
                _buildInfoRow(Icons.email_outlined, _email, 'Почта'),
                const Divider(),
                _buildInfoRow(
                  Icons.description_outlined,
                  _description ?? 'Не указано',
                  'Описание',
                  onEdit: _navigateToEditDescription
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

  Widget _buildInfoRow(
    IconData icon, 
    String value, 
    String label, 
    {VoidCallback? onEdit}
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
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
            tooltip: 'Редактировать',
          ),
      ],
    );
  }

  void _navigateToEditDescription() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDescriptionPage(
          currentDescription: _description ?? '',
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadProfile();
    }
  }

}