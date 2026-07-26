import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/add_members_screen.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/users_profile_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  final String _baseURL = "http://45.132.255.102:8000/";
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _token = await _getToken();
    if (_token == null) {
      setState(() => _isLoading = false);
      return;
    }
    await Future.wait([_getMembers(widget.groupId), _getGroup(widget.groupId)]);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _isLoading = value);
  }

  Future<void> _getMembers(int groupId) async {
    try {
      final response = await _api.getGroupMembers(_token!, groupId);
      final bool isSuccess = response["success"] == true;
      final String message = response["message"] ?? "Ошибка";

      if (isSuccess) {
        final data = response["data"];
        setState(() {
          _members = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        _showError('Ошибка: $message');
      }
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  Future<void> _getGroup(int groupId) async {
    try {
      final response = await _api.getGroupDetails(_token!, groupId);
      final bool isSuccess = response["success"] == true;
      final String message = response["message"] ?? "Ошибка";

      if (isSuccess) {
        final data = response["data"];
        setState(() {
          _isLoading = false;
          _groupName = data["name"] ?? "Неизвестно";
          _description = data["description"] ?? "Неизвестно";
          _avatarPath = data["avatar_path"] ?? "";
          _createdAt = data["created_at"];
          _membersCount = data["member_count"];
        });
      } else {
        _showError('Ошибка: $message');
      }
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  Future<void> _kickMemberApi(int memberId) async {
    try {
      final response = await _api.kickUserFromGroup(_token!, widget.groupId, [
        memberId,
      ]);
      final bool isSuccess = response["success"] == true;
      final String message = response["message"] ?? "Ошибка";

      if (isSuccess) {
        setState(() {
          _members.removeWhere((m) => (m["id"] ?? m["user_id"]) == memberId);
          _membersCount = _members.length;
        });
        _showSuccess(message);
      } else {
        _showError('Ошибка: $message');
      }
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  Future<bool> _updateGroupNameApi(String newName) async {
    try {
      final response = await _api.updateGroupName(
        _token!,
        widget.groupId,
        newName,
      );
      final bool isSuccess = response["success"] == true;
      final String message = response["message"] ?? "Ошибка";

      if (isSuccess) {
        setState(() {
          _groupName = newName;
          _isLoading = false;
        });
        _showSuccess(message);
        return true;
      } else {
        _showError('Ошибка: $message');
        return false;
      }
    } catch (e) {
      _showError('Ошибка: $e');
      return false;
    }
  }

  Future<bool> _updateGroupDescriptionApi(String newDescription) async {
    try {
      final response = await _api.updateGroupDescription(
        _token!,
        widget.groupId,
        newDescription,
      );
      final bool isSuccess = response["success"] == true;
      final String message = response["message"] ?? "Ошибка";

      if (isSuccess) {
        setState(() {
          _description = newDescription;
          _isLoading = false;
        });
        _showSuccess(message);
        return true;
      } else {
        _showError('Ошибка: $message');
        return false;
      }
    } catch (e) {
      _showError('Ошибка: $e');
      return false;
    }
  }

  Future<void> _uploadAvatarApi(String filePath) async {
    try {
      _setLoading(true);
      final response = await _api.changeGroupAvatar(
        _token!,
        widget.groupId,
        File(filePath),
      );
      final bool isSuccess = response["success"] == true;
      final String message = response["message"] ?? "Ошибка";

      if (isSuccess) {
        setState(() {
          _avatarPath = response["data"]?["avatar_path"] ?? "";
          _isLoading = false;
        });
        _showSuccess(message);
      } else {
        _setLoading(false);
        _showError(message);
      }
    } catch (e) {
      _setLoading(false);
      _showError('Ошибка: $e');
    }
  }

  Future<void> _deleteAvatarApi() async {
    try {
      _setLoading(true);
      final response = await _api.deleteGroupAvatar(_token!, widget.groupId);
      final bool isSuccess = response["success"] == true;
      final String message = response["message"] ?? "Ошибка";

      if (isSuccess) {
        setState(() {
          _avatarPath = "";
          _isLoading = false;
        });
        _showSuccess(message);
      } else {
        _setLoading(false);
        _showError(message);
      }
    } catch (e) {
      _setLoading(false);
      _showError('Ошибка: $e');
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    String confirmText = 'Подтвердить',
    Color confirmColor = Colors.redAccent,
    IconData titleIcon = Icons.warning_rounded,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(titleIcon, color: confirmColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<String?> _showEditDialog({
    required String title,
    required String initialValue,
    required IconData titleIcon,
    int maxLength = 50,
    int maxLines = 1,
    String hintText = 'Введите значение...',
    String emptyErrorText = 'Значение не может быть пустым',
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(titleIcon, color: Colors.blue),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            alignLabelWithHint: maxLines > 1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                _showError(emptyErrorText);
                return;
              }
              Navigator.pop(dialogContext, text);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _kickMember(int memberId, String memberName) async {
    final confirmed = await _showConfirmDialog(
      title: 'Исключить?',
      content:
          'Вы уверены, что хотите исключить "$memberName" из группы?\n\nЭто действие нельзя будет отменить.',
      confirmText: 'Исключить',
    );
    if (confirmed == true) {
      await _kickMemberApi(memberId);
    }
  }

  Future<void> _editGroupName() async {
    final newName = await _showEditDialog(
      title: 'Смена названия',
      initialValue: _groupName,
      titleIcon: Icons.edit,
      maxLength: 20,
      hintText: 'Введите новое название...',
      emptyErrorText: 'Название не может быть пустым',
    );
    if (newName == null) return;

    _setLoading(true);
    final success = await _updateGroupNameApi(newName);
    if (!success && mounted) _setLoading(false);
  }

  Future<void> _editGroupDescription() async {
    final initial = _description == "Неизвестно" ? "" : _description;
    final newDescription = await _showEditDialog(
      title: 'Смена описания',
      initialValue: initial,
      titleIcon: Icons.description,
      maxLength: 100,
      maxLines: 5,
      hintText: 'Введите новое описание...',
      emptyErrorText: 'Описание не может быть пустым',
    );
    if (newDescription == null) return;

    _setLoading(true);
    final success = await _updateGroupDescriptionApi(newDescription);
    if (!success && mounted) _setLoading(false);
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        _showError('На веб-платформах требуется дополнительная обработка');
        return;
      }
      await _uploadAvatarApi(filePath);
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  Future<void> _confirmDeleteAvatar() async {
    final confirmed = await _showConfirmDialog(
      title: 'Удалить?',
      content:
          'Вы уверены, что хотите удалить аватарку группы?\n\nЭто действие нельзя будет отменить.',
      confirmText: 'Удалить',
    );
    if (confirmed == true) {
      await _deleteAvatarApi();
    }
  }

  Future<void> _openAddMembers() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMembersScreen(groupId: widget.groupId, groupName: _groupName),
      ),
    );
    if (result == true && mounted) {
      await _getMembers(widget.groupId);
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Удалить группу?'),
          ],
        ),
        content: const Text(
          'Все сообщения и участники будут удалени безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm == true && _token != null) {
      try {
        setState(() => _isLoading = true);

        final ApiService apiService = ApiService();
        final response = await apiService.deleteGroup(_token!, widget.groupId);

        if (response['success'] == true) {
          String message = response["message"];
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['message'] ?? 'Ошибка при выходе из группы',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О группе'),
        actions: [
          IconButton(
            onPressed: _deleteGroup,
            icon: Icon(Icons.delete_outline_rounded),
            color: Colors.red,
            tooltip: "Удалить группу",
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildContentView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
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
    );
  }

  Widget _buildContentView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvatarSection(),
            const SizedBox(height: 16),
            _buildAvatarButtons(),
            const SizedBox(height: 10),
            _buildNameSection(),
            _buildMetaSection(),
            const SizedBox(height: 25),
            _buildDescriptionSection(),
            const SizedBox(height: 25),
            _buildMembersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return GestureDetector(
      onTap: _showFullAvatar,
      child: CircleAvatar(
        radius: 50,
        backgroundImage: _avatarPath.isNotEmpty
            ? NetworkImage("$_baseURL$_avatarPath") as ImageProvider
            : null,
        child: _avatarPath.isEmpty
            ? const Icon(LucideIcons.users, size: 50)
            : null,
      ),
    );
  }

  Widget _buildAvatarButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: _pickAndUploadAvatar,
            icon: const Icon(LucideIcons.switchCamera, size: 20),
            label: const Text('Изменить'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
            )
          ),
        ),
        if (_avatarPath.isNotEmpty) ...[
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _confirmDeleteAvatar,
              icon: const Icon(LucideIcons.trash2, size: 20),
              label: const Text('Удалить'),
              style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            )
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNameSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 60),
        Flexible(
          child: Text(
            _groupName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            icon: const Icon(Icons.edit, size: 20,), 
            onPressed: _editGroupName,
            padding: EdgeInsets.zero,
          ),
        )
        
      ],
    );
  }

  Widget _buildMetaSection() {
    return Column(
      children: [
        Text(
          "Кол-во участников: $_membersCount",
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Text(
          "Группа создана ${_formatDate(_createdAt)}",
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded, size: 20,),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Описание',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20,),
                  onPressed: _editGroupDescription,
                  padding: EdgeInsets.zero,
                ),
              )
              
            ],
          ),
          const Divider(height: 15),
          SelectionArea(
            child: Text(
              _description,
              style: const TextStyle(fontSize: 15, height: 1.6),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _openAddMembers,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    foregroundColor: Colors.blue
                  ),
                  child: const Text("Добавить участников"),
                ),
              ),
            ),
            const Divider(),
            if (_members.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "В группе пока нет участников",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ..._buildMembersList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMembersList() {
    final items = <Widget>[];
    for (var i = 0; i < _members.length; i++) {
      final member = _members[i];
      final id = member["id"] ?? member["user_id"];
      final username = member["username"] ?? member["name"] ?? "Без имени";
      final avatarPath = member["avatar_path"] ?? "";
      final role = member["role"] ?? "member";
      final joinedAt = _formatDate(member["joined_at"]);

      items.add(
        _buildInfoRow(
          LucideIcons.user,
          username,
          'Присоединился: $joinedAt',
          avatarPath: avatarPath,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UsersProfileScreen(userId: id),
              ),
            );
          },
          onEdit: id != null ? () => _kickMember(id, username) : null,
          roleLabel: role,
        ),
      );
      if (i < _members.length - 1) items.add(const Divider());
    }
    return items;
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
            icon: const Icon(LucideIcons.userX, size: 16),
            label: const Text("Кик"),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
      ],
    );
  }

  Widget _buildRoleBadge({required String label, required Color color}) {
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
            if (loadingProgress == null) return child;
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
      DateTime dateTime = DateTime.parse('${dateString}Z');
      if (dateTime.isUtc) dateTime = dateTime.toLocal();

      const months = [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря',
      ];

      final day = dateTime.day.toString();
      final month = months[dateTime.month - 1];
      final year = dateTime.year.toString();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day $month $year г. в $hour:$minute';
    } catch (e) {
      return "Неизвестно";
    }
  }

  void _showFullAvatar() {
    if (_avatarPath.isEmpty) return;

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
