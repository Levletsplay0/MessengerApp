import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "http://45.132.255.102:8000";

  Future<Map<String, dynamic>> getServer() async {
    final Uri url = Uri.parse(baseUrl);
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    }
    catch (e){
      throw Exception('Ошибка: $e');
    }
    
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final Uri url = Uri.parse("$baseUrl/login");
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "username": username,
          "password": password
        })
      );

      return jsonDecode(response.body);
    }
    catch(e){
      throw Exception('Ошибка: $e');
    }
    
  }

  Future<Map<String, dynamic>> register(String username, String password, String email) async {
    final Uri url = Uri.parse('$baseUrl/register');
    
    try{
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": username,
          "password": password,
          "email": email
        }),
      );

      return jsonDecode(response.body);
    }
    catch(e){
      throw Exception('Ошибка: $e');
    }
    
  }

  Future<Map<String, dynamic>> getGroups(String token) async {
    final Uri url = Uri.parse('$baseUrl/groups');
    
    try{
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          "auth-token": token
        },
        
      );

      return jsonDecode(response.body);
    }
    catch(e){
      throw Exception('Ошибка: $e');
    }
    
  }

    Future<Map<String, dynamic>> getMe(String token) async {
    final Uri url = Uri.parse('$baseUrl/users/me');
    
    try{
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          "auth-token": token
        },
        
      );

      return jsonDecode(response.body);
    }
    catch(e){
      throw Exception('Ошибка: $e');
    }
    
  }
  


}