import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/edit_profile_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String? _error;

  int? _userId;
  String _username = '';
  String _email = '';
  String _name = '';
  String _lastName = '';
  String? _avatarPath;
  String _description = '';
  String? _dateOfBirth;

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
        if (!mounted) return;
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
          if (!mounted) return;
          setState(() {
            _error = 'Данные профиля пусты';
            _isLoading = false;
          });
          return;
        }
        if (!mounted) return;
        setState(() {
          _userId = data["id"] ?? '';
          _username = data["username"] ?? '';
          _email = data["email"] ?? '';
          _name = data["name"] ?? '';
          _lastName = data["last_name"] ?? '';
          _avatarPath = data["avatar_path"];
          _description = data["description"];
          _dateOfBirth = data["date_of_birth"];
          _isLoading = false;
        });
      } else {
        final message = response["message"] ?? 'Неизвестная ошибка';
        if (!mounted) return;
        setState(() {
          _error = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (!mounted) return;
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
    } catch (e) {
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
          const SnackBar(
            content: Text(
              'На веб-платформах требуется дополнительная обработка',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                if (!mounted) return;
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
            Text(
              "Id: $_userId",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                  icon: const Icon(LucideIcons.image),
                  onPressed: _pickAndUploadImage,
                  style: OutlinedButton.styleFrom(
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    foregroundColor: Colors.blue
                  ),
                  label: const Text(
                    "Изменить фото",
                    style: TextStyle(
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: _deleteAvatar,
                  style: OutlinedButton.styleFrom(
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    foregroundColor: Colors.red
                  ),
                  label: const Text(
                    "Удалить фото",
                    style: TextStyle(
                      fontWeight: FontWeight.bold
                    ),
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
                _buildInfoRow(
                  LucideIcons.user,
                  _username,
                  'Имя пользователя',
                ),
                const Divider(),
                _buildInfoRow(
                  LucideIcons.mail, 
                  _email, 
                  'Почта'
                ),
                const Divider(),
                _buildInfoRow(
                  LucideIcons.bookUser,
                  _description,
                  'Описание',
                ),
                const Divider(),
                _buildInfoRow(
                  LucideIcons.calendarFold,
                  (_dateOfBirth == null || _dateOfBirth!.isEmpty)
                      ? 'Не указана'
                      : DateFormat('dd.MM.yyyy').format(DateTime.parse(_dateOfBirth!)),
                  'Дата рождения',
                ),
                const Divider(),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _navigateToEditProfile, 
                    label: Text("Редактировать профиль"), 
                    icon: Icon(LucideIcons.squarePen),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
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
            : const Icon(LucideIcons.user, size: 50),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value, String label, ) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToEditProfile() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentName: _name,
          currentLastName: _lastName,
          currentDescription: _description,
          currentDateOfBirth: _dateOfBirth,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadProfile();
      }
    });
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
                      return const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
                      );
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
