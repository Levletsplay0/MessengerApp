import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "http://45.132.255.102:8000";

  Future<Map<String, dynamic>> getServer() async {
    final Uri url = Uri.parse(baseUrl);
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final Uri url = Uri.parse("$baseUrl/login");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"username": username, "password": password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> register(String username, String password, String email, String name, String lastName) async {
    final Uri url = Uri.parse('$baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": username,
          "password": password,
          "email": email,
          "name": name,
          "last_name": lastName,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> getGroups(String token) async {
    final Uri url = Uri.parse('$baseUrl/groups');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json', "auth-token": token});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    final Uri url = Uri.parse('$baseUrl/users/me');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json', "auth-token": token});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAvatar(String token) async {
    final Uri url = Uri.parse('$baseUrl/users/me/avatar');
    try {
      final response = await http.delete(url, headers: {'Content-Type': 'application/json', 'auth-token': token});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> changeAvatar(String token, File imageFile) async {
    final Uri url = Uri.parse('$baseUrl/users/me/avatar');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['auth-token'] = token;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path, filename: imageFile.path.split('/').last));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      throw Exception('Ошибка при загрузке аватара: $e');
    }
  }

  Future<Map<String, dynamic>> updateDescription(String token, String description) async {
    final Uri url = Uri.parse('$baseUrl/users/me/description');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
        body: jsonEncode({"description": description}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  // === Новые методы для чата ===

  Future<Map<String, dynamic>> getGroupDetails(String token, int groupId) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'auth-token': token});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> getMessages(String token, int groupId, {int limit = 50, int offset = 0}) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/messages?limit=$limit&offset=$offset');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'auth-token': token});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> sendMessage(String token, int groupId, String content, {File? file}) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/messages');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['auth-token'] = token;
      request.fields['content'] = content;

      if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path, filename: file.path.split('/').last),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      throw Exception('Ошибка отправки: $e');
    }
  }

  Future<Map<String, dynamic>> editMessage(String token, int groupId, int messageId, String content) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/messages/$messageId');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
        body: jsonEncode({"content": content}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> deleteMessage(String token, int groupId, int messageId) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/messages/$messageId');
    try {
      final response = await http.delete(url, headers: {'Content-Type': 'application/json', 'auth-token': token});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> getGroupMembers(String token, int groupId) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/members');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'auth-token': token});
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> kickUserFromGroup(String token, int groupId, List<int> userIds) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/kick');
    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json', 'auth-token': token}, 
        body: jsonEncode({"user_ids": userIds}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> searchUsers(String token, String username, {int limit = 20, int offset = 0}) async {
    final Uri url = Uri.parse('$baseUrl/users/search?username=$username&limit=$limit&offset=$offset');
    try {
      final response = await http.get(
        url, 
        headers: {'Content-Type': 'application/json', 'auth-token': token},
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> addGroupMembers(String token, int groupId, List<int> userIds) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/members');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
        body: jsonEncode({"user_ids": userIds}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> updateGroupDescription(String token, int groupId, String description) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/description');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
        body: jsonEncode({"description": description}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> updateGroupName(String token, int groupId, String name) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/name');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
        body: jsonEncode({"name": name}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> changeGroupAvatar(String token, int groupId, File imageFile) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/avatar');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['auth-token'] = token;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path, filename: imageFile.path.split('/').last),
      );
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      throw Exception('Ошибка при загрузке аватара группы: $e');
    }
  }

  Future<Map<String, dynamic>> deleteGroupAvatar(String token, int groupId) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/avatar');
    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> getUserDetails(String token, int userId) async {
    final Uri url = Uri.parse('$baseUrl/users/$userId');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> leaveUserFromGroup(String token, int groupId) async {
    final Uri url = Uri.parse('$baseUrl/groups/$groupId/leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }

  Future<Map<String, dynamic>> createGroup(String token, String name) async {
    final Uri url = Uri.parse('$baseUrl/groups');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'auth-token': token},
        body: jsonEncode({"name": name}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Ошибка: $e');
    }
  }
  
}