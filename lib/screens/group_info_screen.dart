import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({super.key});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPage();
}

class _GroupInfoPage extends State<GroupInfoPage> {
  
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _login() async {
    try {
      final api = ApiService();
      final response = await api.login("username", "password");
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
            CircleAvatar(radius: 50,),
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
                fontSize: 14,
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
                        child: OutlinedButton(
                          onPressed: (){}, 
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
                          child: Text("Добавить участников"),
                        ),
                      )
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.person, "Имя участника", 'Joined at', onEdit: (){}),
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
        CircleAvatar(radius: 16,),
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
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: Icon(Icons.arrow_upward),
            label: Text("Кик"),
          ),
      ],
    );
  }


}