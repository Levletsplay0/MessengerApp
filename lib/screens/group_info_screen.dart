import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/add_members_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupInfoPage extends StatefulWidget {
  final int groupId;
  const GroupInfoPage({super.key, required this.groupId});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPage();
}

class _GroupInfoPage extends State<GroupInfoPage> {
  String? _token;
  bool _isLoading = true;
  String _groupName = "Неизвестно";
  int _membersCount = 0;
  List<dynamic> _members = [];
  String? _createdAt = "?";
  String _description = "Неизвестно";
  String _avatarPath = "";
  String _baseURL = "http://45.132.255.102:8000/";
  String _creatorId = "Неизвестно";

  @override
  void initState() {
    super.initState();
    _getMembers(widget.groupId);
    _getGroup(widget.groupId);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getMembers(int groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final api = ApiService();
      final response = await api.getGroupMembers(_token!, groupId);
      bool isSuccess = response["success"];
      String message = response["message"] ?? "Ошибка";

      if (isSuccess == true) {
        final data = response["data"];

        setState(() {
          _isLoading = false;
          _members = data is List ? data : [];
          _membersCount = _members.length;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $message'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _getGroup(int groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final api = ApiService();
      final response = await api.getGroupDetails(_token!, groupId);
      bool isSuccess = response["success"];
      String message = response["message"] ?? "Ошибка";

      if (isSuccess == true) {
        setState(() {
          _isLoading = false;
        });

        final data = response["data"];
        _groupName = data["name"] ?? "Неизвестно";
        _description = data["description"] ?? "Неизвестно";
        _avatarPath = data["avatar_path"] ?? "";
        _creatorId = data["creator_id"]?.toString() ?? "Неизвестно";
        _createdAt = data["created_at"];
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $message'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

void _kickMember(int memberId, String memberName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Исключить?'),
          ],
        ),
        content: Text(
            'Вы уверены, что хотите исключить "$memberName" из группы?\n\nЭто действие нельзя будет отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              try {
                final api = ApiService();
                final response = await api.kickUserFromGroup(_token!, widget.groupId, [memberId]);
                bool isSuccess = response["success"];
                final message = response["message"];

                if (mounted) {
                  if (isSuccess) {
                    setState(() {
                      _members.removeWhere((m) => m["id"] == memberId);
                      _membersCount = _members.length;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $message'), backgroundColor: Colors.red),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Исключить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О группе'),
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.edit))],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка информации о группе...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _avatarPath.isNotEmpty
                        ? NetworkImage("$_baseURL$_avatarPath") as ImageProvider
                        : null,
                    child: _avatarPath.isEmpty
                        ? const Icon(Icons.group, size: 50, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _groupName,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Кол-во участников: $_membersCount",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    "Группа создана ${_formatDate(_createdAt)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Card(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.blue.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectionArea(
                            child: Text(
                              _description,
                              style: TextStyle(
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                          SizedBox(height: 16),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              "Описание",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddMembersScreen(
                                        groupId: widget.groupId,
                                        groupName: _groupName,
                                      ),
                                    ),
                                  );

                                  if (result == true && mounted) {
                                    _getMembers(widget.groupId);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text("Добавить участников"),
                              ),
                            ),
                          ),
                          const Divider(),
                          _members.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Text(
                                      "В группе пока нет участников",
                                      style: TextStyle(color: Colors.grey, fontSize: 14),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: _members.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final member = entry.value;
                                    final id = member["id"] ?? member["user_id"];
                                    final username = member["username"] ?? member["name"] ?? "Без имени";
                                    final avatarPath = member["avatar_path"] ?? "";
                                    final role = member["role"] ?? "member";
                                    final joinedAt = _formatDate(member["joined_at"]);

                                    return Column(
                                      children: [
                                        _buildInfoRow(
                                          Icons.person,
                                          username,
                                          'Присоединился: $joinedAt',
                                          avatarPath: avatarPath,
                                          onTap: () {
                                            print("Открытие профиля");
                                          },
                                          onEdit: id != null
                                              ? () => _kickMember(id, username)
                                              : null,
                                          roleLabel: role
                                        ),
                                        if (index < _members.length - 1)
                                          const Divider(),
                                      ],
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String value,
    String label, {
    String? avatarPath,
    VoidCallback? onEdit,
    VoidCallback? onTap,
    String? roleLabel,
    Color? roleColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                _buildAvatarWithLoader(
                  avatarPath: avatarPath,
                  icon: icon,
                  radius: 18,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (roleLabel != null && roleLabel.isNotEmpty)
                            _buildRoleBadge(
                              label: roleLabel,
                              color: roleColor ?? Colors.blue,
                            ),
                        ],
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
            ),
          ),
        ),
        
        if (onEdit != null)
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: const Text("Кик"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
          ),
      ],
    );
  }

  Widget _buildRoleBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)), 
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildAvatarWithLoader({
    String? avatarPath,
    required IconData icon,
    required double radius,
  }) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Icon(icon, size: radius * 0.9, color: Colors.grey[600]),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.network(
          "$_baseURL$avatarPath",
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: Colors.grey[600],
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(icon, size: radius * 0.9, color: Colors.grey[600]);
          },
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty || dateString == "0") {
      return "Неизвестно";
    }

    try {
      dateString = '${dateString}Z';

      DateTime dateTime = DateTime.parse(dateString);

      if (dateTime.isUtc) {
        dateTime = dateTime.toLocal();
      }

      const months = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
      ];

      String day = dateTime.day.toString();
      String month = months[dateTime.month - 1];
      String year = dateTime.year.toString();
      String hour = dateTime.hour.toString().padLeft(2, '0');
      String minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day $month $year г. в $hour:$minute';
    } catch (e) {
      return "Неизвестно";
    }
  }
}