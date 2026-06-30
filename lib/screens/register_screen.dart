import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isPasswordVisible = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  
  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    String email = _emailController.text.trim();
    String username = _usernameController.text.trim();
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;
    String name = _nameController.text;
    String lastName = _lastNameController.text;


    if (email.isEmpty || username.isEmpty || password.isEmpty || confirmPassword.isEmpty || name.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    if(password != confirmPassword){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароли не совпали'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    try {
      final api = ApiService();
      final response = await api.register(username, password, email, name, lastName);
      bool isSuccess = response["success"];
      String message = response["message"];
      if (isSuccess == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успех: $message'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
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
        title: const Text('Регистрация'),
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 25,),
            Icon(Icons.person_add, size: 75,),
            const SizedBox(height: 5,),
            Text(
              "Регистрация",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: 25,),
            SizedBox(
              width: 300,
              child: TextField(
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Почта",
                  prefixIcon: Icon(Icons.email),
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            SizedBox(height: 25,),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: "Имя пользователя",
                  prefixIcon: const Icon(Icons.person),
                  fillColor: Colors.transparent,
                ),
                
              ),
            ),
            SizedBox(height: 25,),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Пароль",
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible 
                          ? Icons.visibility_off 
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  fillColor: Colors.transparent,
                ),
                
              ),
            ),
            SizedBox(height: 25,),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _confirmPasswordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Повторите пароль",
                  prefixIcon: const Icon(Icons.password),
                  fillColor: Colors.transparent,
                  
                ),
                
              ),
            ),
            SizedBox(height: 25,),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Имя",
                  prefixIcon: const Icon(Icons.text_format_outlined),
                  fillColor: Colors.transparent,
                  
                ),
                
              ),
            ),
            SizedBox(height: 25,),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: "Фамилия",
                  prefixIcon: const Icon(Icons.text_format_outlined),
                  fillColor: Colors.transparent,
                  
                ),
                
              ),
            ),
            SizedBox(height: 25,),
            SizedBox(
              width: 300,
              child: 
                OutlinedButton(
                  onPressed: _register,
                  child: const Text('Зарегистрироваться'),
                ),
            ),
            SizedBox(height: 25,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Зарегистрированы? ",
                  style: TextStyle(color: Colors.grey),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    "Войти",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
          ],
        )
      ),
    );
  }
}