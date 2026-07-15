import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Не авторизован')));
        }
        return;
      }

      final api = ApiService();
      final response = await api.createGroup(
        token,
        _nameController.text.trim(),
      );

      final isSuccess = response["success"];
      String message = response["message"] ?? 'Неизвестная ошибка';

      if (isSuccess == true) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка: $message')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создать группу')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Придумайте прекрасное название для вашей группы",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Icon(Icons.groups_2_outlined, size: 80),
              const SizedBox(height: 32),
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Название группы",
                    hintText: 'Введите название группы',
                    prefixIcon: const Icon(Icons.group),
                    fillColor: Colors.transparent,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название группы';
                    }
                    if (value.trim().length < 3) {
                      return 'Название должно содержать минимум 3 символа';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _isLoading ? null : _createGroup,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Создать группу'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
