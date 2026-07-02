import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String? groupAvatar;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _error;
  String? _token;
  int? _currentUserId;
  File? _selectedFile;
  bool _isSending = false;
  StreamSubscription? _wsSubscription;
  String? _groupAvatarPath;
  String? _groupDescription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');

    if (_token == null) {
      setState(() {
        _error = 'Не авторизован';
        _isLoading = false;
      });
      return;
    }

    try {
      final meResponse = await _apiService.getMe(_token!);
      if (meResponse['success'] == true) {
        _currentUserId = meResponse['data']?['id'];
      }
    } catch (e) {
      print('Ошибка получения данных пользователя: $e');
    }

    await _loadGroupDetails();
    await _loadMessages();

    _wsService.connect('http://45.132.255.102:8000', widget.groupId, _token!);

    _wsSubscription = _wsService.messageStream.listen((message) {
      _handleWebSocketMessage(message);
    });
  }

  Future<void> _loadGroupDetails() async {
    try {
      final response = await _apiService.getGroupDetails(_token!, widget.groupId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _groupAvatarPath = response['data']['avatar_path'];
          _groupDescription = response['data']['description'];
        });
      }
    } catch (e) {
      print('Ошибка загрузки деталей группы: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _apiService.getMessages(_token!, widget.groupId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _messages = List.from(response['data']);
          _messages.sort((a, b) {
            final dateA = DateTime.parse(a['sent_at']);
            final dateB = DateTime.parse(b['sent_at']);
            return dateA.compareTo(dateB);
          });
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Ошибка загрузки';
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

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];
    final data = message['data'];

    if (type == 'new_message' && data != null) {
      if (data['group_id'] == widget.groupId) {
        setState(() {
          final exists = _messages.any((m) => m['id'] == data['id']);
          if (!exists) {
            _messages.add(data);
            _messages.sort((a, b) {
              final dateA = DateTime.parse(a['sent_at']);
              final dateB = DateTime.parse(b['sent_at']);
              return dateA.compareTo(dateB);
            });
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } else if (type == 'edit_message' && data != null) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == data['id']);
        if (index != -1) {
          _messages[index] = data;
        }
      });
    } else if (type == 'delete_message' && data != null) {
      setState(() {
        _messages.removeWhere((m) => m['id'] == data['id']);
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedFile == null) return;

    setState(() => _isSending = true);

    try {
      if (_selectedFile != null) {
        final response = await _apiService.sendMessage(
          _token!,
          widget.groupId,
          content,
          file: _selectedFile,
        );
        if (response['success'] == true && response['data'] != null) {
          setState(() {
            final exists = _messages.any((m) => m['id'] == response['data']['id']);
            if (!exists) {
              _messages.add(response['data']);
              _messages.sort((a, b) {
                final dateA = DateTime.parse(a['sent_at']);
                final dateB = DateTime.parse(b['sent_at']);
                return dateA.compareTo(dateB);
              });
            }
          });
          _scrollToBottom();
        }
      } else {
        _wsService.sendTextMessage(content);
      }

      _messageController.clear();
      setState(() => _selectedFile = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      print('Ошибка выбора файла: $e');
    }
  }

  void _showMessageOptions(dynamic message) {
    final isOwn = message['author_id'] == _currentUserId;
    final hasFile = message['file'] != null && message['file'] is Map;
    final content = message['content']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: Theme.of(context).colorScheme.primary),
                title: const Text('Копировать текст'),
                onTap: () {
                  Navigator.pop(context);
                  if (content.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Текст скопирован'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              if (hasFile)
                ListTile(
                  leading: Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Скачать файл'),
                  onTap: () {
                    Navigator.pop(context);
                    final filePath = message['file']['path'];
                    _downloadFile(filePath);
                  },
                ),
              if (isOwn) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Редактировать'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                  title: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message['id']);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(dynamic message) {
    final controller = TextEditingController(text: message['content'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Редактировать сообщение'),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 6,
          minLines: 3,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Введите новое сообщение...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty) {
                _wsService.editMessage(message['id'], newContent);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Сообщение обновлено'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Удалить сообщение?'),
          ],
        ),
        content: const Text('Это действие нельзя будет отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _wsService.deleteMessage(messageId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сообщение удалено'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarPath = _groupAvatarPath ?? widget.groupAvatar;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            _buildGroupAvatar(widget.groupName, avatarPath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_groupDescription != null && _groupDescription!.isNotEmpty)
                    Text(
                      _groupDescription!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _wsService.isConnected ? Colors.greenAccent : Colors.redAccent,
                  boxShadow: _wsService.isConnected
                      ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 6)]
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text('Ошибка: $_error', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _error = null;
                                });
                                _loadMessages();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Нет сообщений', style: TextStyle(fontSize: 18, color: Colors.grey)),
                                SizedBox(height: 8),
                                Text('Будьте первым, кто напишет!', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isOwn = message['author_id'] == _currentUserId;
                              final showDate = index == 0 || _shouldShowDateSeparator(index);

                              return Column(
                                children: [
                                  if (showDate) _buildDateSeparator(message['sent_at']),
                                  _buildMessageBubble(message, isOwn),
                                ],
                              );
                            },
                          ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return false;
    final current = DateTime.parse(_messages[index]['sent_at']);
    final previous = DateTime.parse(_messages[index - 1]['sent_at']);
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Widget _buildDateSeparator(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    String text;

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      text = 'Сегодня';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      text = 'Вчера';
    } else {
      text = DateFormat('dd.MM.yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic message, bool isOwn) {
    final content = message['content'] ?? '';
    final sentAt = DateTime.parse(message['sent_at']);
    final timeStr = DateFormat('HH:mm').format(sentAt);
    final isEdited = message['edited_at'] != null;
    final authorName = message['author_name'] ?? message['author_username'] ?? 'Пользователь';

    String? filePath;
    String? fileName;

    if (message['file'] != null && message['file'] is Map) {
      final fileData = message['file'] as Map<String, dynamic>;
      filePath = fileData['path'];
      fileName = fileData['name'] ?? 'Файл';
    }

    final hasFile = filePath != null && filePath.isNotEmpty && filePath != 'null';

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(message),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isOwn
                ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
                : Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]
                    : Colors.grey[200],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isOwn ? 18 : 4),
              bottomRight: Radius.circular(isOwn ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isOwn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    authorName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if (hasFile)
                _buildFileAttachment(filePath!, fileName!),
              if (content.isNotEmpty)
                SelectableText(
                  content,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdited)
                    const Text(
                      'изменено ',
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileAttachment(String filePath, String fileName) {
    final baseUrl = 'http://45.132.255.102:8000';
    final fileUrl = filePath.startsWith('http') ? filePath : '$baseUrl/$filePath';

    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.gif') ||
        fileName.toLowerCase().endsWith('.webp');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: isImage
            ? _buildImagePreview(fileUrl, fileName)
            : _buildFilePreviewWidget(fileName),
      ),
    );
  }

  Widget _buildImagePreview(String url, String fileName) {
    return GestureDetector(
      onTap: () => _showImageFullScreen(url),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
        child: Stack(
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey[850],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  color: Colors.grey[850],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey[600]),
                      const SizedBox(height: 8),
                      Text('Не удалось загрузить',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                  ),
                ),
                child: Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreviewWidget(String fileName) {
    IconData fileIcon;
    Color iconColor;

    if (fileName.toLowerCase().endsWith('.pdf')) {
      fileIcon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.redAccent;
    } else if (fileName.toLowerCase().endsWith('.doc') || fileName.toLowerCase().endsWith('.docx')) {
      fileIcon = Icons.description_rounded;
      iconColor = Colors.blueAccent;
    } else if (fileName.toLowerCase().endsWith('.mp4') || fileName.toLowerCase().endsWith('.avi')) {
      fileIcon = Icons.video_file_rounded;
      iconColor = Colors.purpleAccent;
    } else if (fileName.toLowerCase().endsWith('.mp3') || fileName.toLowerCase().endsWith('.wav')) {
      fileIcon = Icons.audio_file_rounded;
      iconColor = Colors.orangeAccent;
    } else {
      fileIcon = Icons.insert_drive_file_rounded;
      iconColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _downloadFile(fileName),
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.grey[100],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fileIcon, size: 32, color: iconColor),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileType(fileName),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_rounded, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  String _formatFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return 'Изображение • ${extension.toUpperCase()}';
    } else if (['mp4', 'avi', 'mov'].contains(extension)) {
      return 'Видео • ${extension.toUpperCase()}';
    } else if (['mp3', 'wav', 'ogg'].contains(extension)) {
      return 'Аудио • ${extension.toUpperCase()}';
    } else if (extension == 'pdf') {
      return 'PDF документ';
    }
    return 'Файл • ${extension.toUpperCase()}';
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () => _downloadFile(imageUrl.split('/').last),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text('Не удалось загрузить изображение',
                        style: TextStyle(color: Colors.white)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _downloadFile(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скачивание: $fileName'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // === ОБНОВЛЕННАЯ ПАНЕЛЬ ВВОДА ===
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedFile != null) _buildSelectedFilePreview(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Кнопка прикрепления файла

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white, // цвет обводки
                      width: 2.0, // толщина обводки
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _pickFile,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          _selectedFile != null ? Icons.file_copy : Icons.attach_file_rounded,
                          color: _selectedFile != null 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.grey[500],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 6),

                // Поле ввода "Капсула"
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                      isDense: true,

                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 6),

                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 200,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : () => _sendMessage(),
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFilePreview() {
    final fileName = _selectedFile!.path.split('/').last;
    final extension = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
    final nameWithoutExt = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.insert_drive_file_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameWithoutExt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  extension.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedFile = null),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatar(String name, String? avatarPath) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage('http://45.132.255.102:8000/$avatarPath'),
      );
    }

    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink
    ];
    final color = colors[name.length % colors.length];

    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        firstLetter,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}