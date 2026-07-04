import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({super.key});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPage();
}

class _GroupInfoPage extends State<GroupInfoPage> {
  bool _isPasswordVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
    try {
      final api = ApiService();
      final response = await api.login(username, password);
      bool isSuccess = response["success"];
      String message = response["message"];
      
      if (isSuccess == true) {
        String token = response["data"]["auth_token"];
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        
        
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $message'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
    catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
    
    
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О группе'),
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 25,),
            CircleAvatar(radius: 40,),
            const SizedBox(height: 5,),
            Text(
              "Название",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold
              ),
            ),
            Text(
              "Кол-во участников",
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey
              ),
            ),
            const SizedBox(height: 25,),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(onPressed: (){}, child: Text("Добавить участников")),
                      )
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.label, "Название группы", 'Название', onEdit: (){}),
                    const Divider(),
                    _buildInfoRow(Icons.description_outlined, "Описание группы", 'Описание', onEdit: (){}),  
                  ],
                ),
              ),
            ),
            
          ],
        )
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


}