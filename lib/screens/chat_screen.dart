import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/screens/group_info_screen.dart';
import 'package:flutter_application_1/screens/users_profile_screen.dart';
import 'package:flutter_application_1/widgets/message_content.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  static const String _baseUrl = 'http://45.132.255.102:8000';

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  final Connectivity _connectivity = Connectivity();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  int _currentOffset = 0;
  String? _error;
  String? _token;
  int? _currentUserId;
  File? _selectedFile;
  bool _isSending = false;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _connectivitySubscription;
  String? _groupAvatarPath;
  String? _groupDescription;
  int _membersCount = 0;
  bool _isConnectedToInternet = true;
  bool _wasDisconnected = false;

  final Map<int, String> _typingUsers = {};
  Timer? _typingDebounceTimer;
  bool _isLocalUserTyping = false;

  String _getFullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$_baseUrl/$path';
  }

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(_onScroll);
    _initConnectivity();
    
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _messageController.text.trim();

    if (text.isEmpty) {
      _stopTyping();
      return;
    }

    if (!_isLocalUserTyping) {
      _wsService.sendTyping();
      _isLocalUserTyping = true;
    }

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    if (_isLocalUserTyping) {
      _wsService.sendStopTyping();
      _isLocalUserTyping = false;
    }
    _typingDebounceTimer?.cancel();
  }

  String _getTypingText() {
    final names = _typingUsers.values.take(2).toList();
    if (names.length == 1) return '${names[0]} печатает...';
    if (names.length == 2) return '${names[0]} и ${names[1]} печатают...';
    return 'Несколько участников печатают...';
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Ошибка проверки подключения: $e');
      _updateConnectionStatus([ConnectivityResult.none]);
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final hasConnection = result.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );

    if (mounted) {
      setState(() {
        _isConnectedToInternet = hasConnection;
      });

      if (!hasConnection) {
        print('Интернет пропал, отключаем WebSocket');
        _wsSubscription?.cancel();
        _wsService.disconnect();
        _wasDisconnected = true;
      } else if (_wasDisconnected) {
        print('Интернет восстановлен, переподключаем WebSocket');
        _wasDisconnected = false;
        _reconnectWebSocket();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Соединение восстановлено')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreMessages &&
        !_isLoading) {
      _loadMoreMessages();
    }
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

    if (_isConnectedToInternet) {
      _wsService.connect(_baseUrl, widget.groupId, _token!);
      _wsSubscription = _wsService.messageStream.listen((message) {
        _handleWebSocketMessage(message);
      });
    }
  }

  Future<void> _loadGroupDetails() async {
    try {
      final response = await _apiService.getGroupDetails(
        _token!,
        widget.groupId,
      );
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _groupAvatarPath = response['data']['avatar_path'];
          _groupDescription = response['data']['description'];
          _membersCount = response["data"]["member_count"];
        });
      }
    } catch (e) {
      print('Ошибка загрузки деталей группы: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _apiService.getMessages(
        _token!,
        widget.groupId,
        50,
        0,
      );
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _messages = List.from(response['data']);
          _messages.sort((a, b) {
            final dateA = DateTime.parse(a['sent_at']);
            final dateB = DateTime.parse(b['sent_at']);
            return dateB.compareTo(dateA);
          });
          _currentOffset = _messages.length;
          _hasMoreMessages = _messages.length >= 50;
          _isLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 150), () {
          _scrollToBottom();
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Ошибка загрузки';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _apiService.getMessages(
        _token!,
        widget.groupId,
        50,
        _currentOffset,
      );

      if (response['success'] == true && response['data'] != null) {
        final newMessages = List.from(response['data']);

        if (newMessages.isEmpty) {
          setState(() {
            _hasMoreMessages = false;
            _isLoadingMore = false;
          });
          return;
        }

        setState(() {
          _messages.addAll(newMessages);
          _messages.sort((a, b) {
            final dateA = DateTime.parse(a['sent_at']);
            final dateB = DateTime.parse(b['sent_at']);
            return dateB.compareTo(dateA);
          });
          _currentOffset += newMessages.length;
          _hasMoreMessages = newMessages.length >= 50;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Ошибка загрузки дополнительных сообщений: $e');
      setState(() {
        _isLoadingMore = false;
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
            _messages.insert(0, data);
          }
          _typingUsers.remove(data['author_id']);
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          _smartScrollToBottom();
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
    else if (type == 'typing' && data != null) {
      setState(() {
        final userId = data['user_id'];
        final username = data['username'] ?? 'Пользователь';
        if (userId != null && userId != _currentUserId) {
          _typingUsers[userId] = username;
        }
      });
    } else if (type == 'stop_typing' && data != null) {
      setState(() {
        final userId = data['user_id'];
        if (userId != null) {
          _typingUsers.remove(userId);
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);

      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _smartScrollToBottom() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.offset <= 100;

      if (isAtBottom) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (!_isConnectedToInternet) {
      _showSnackBar('Нет подключения к интернету');
      return;
    }

    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedFile == null) return;

    _stopTyping();

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
            final exists = _messages.any(
              (m) => m['id'] == response['data']['id'],
            );
            if (!exists) {
              _messages.insert(0, response['data']);
            }
          });
        }
      } else {
        _wsService.sendTextMessage(content);
      }

      _messageController.clear();
      setState(() => _selectedFile = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
      }
    } finally {
      setState(() => _isSending = false);

      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
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
                leading: Icon(
                  Icons.copy_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Копировать'),
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
                  leading: Icon(
                    LucideIcons.arrowDownToLine,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
                  leading: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Редактировать'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(message);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Удалить',
                    style: TextStyle(color: Colors.redAccent),
                  ),
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
            Icon(
              Icons.edit_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Редактировать'),
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
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              if (!_isConnectedToInternet) {
                Navigator.pop(context);
                _showSnackBar('Нет подключения к интернету');
                return;
              }

              final newContent = controller.text.trim();
              if (newContent.isNotEmpty) {
                _wsService.editMessage(message['id'], newContent);
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
            Text('Удалить?'),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!_isConnectedToInternet) {
        _showSnackBar('Нет подключения к интернету');
        return;
      }

      _wsService.deleteMessage(messageId);
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Выйти из группы?'),
          ],
        ),
        content: const Text(
          'Вы покидаете эту группу. Это действие нельзя отменить.',
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
      if (!_isConnectedToInternet) {
        _showSnackBar('Нет подключения к интернету');
        return;
      }

      try {
        _wsSubscription?.cancel();
        _wsService.disconnect();

        setState(() => _isLoading = true);

        final response = await _apiService.leaveUserFromGroup(
          _token!,
          widget.groupId,
        );

        if (response['success'] == true) {
          String message = response["message"];
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                behavior: SnackBarBehavior.floating,
              ),
            );

            Navigator.of(context).pop(true);
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

            _reconnectWebSocket();
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
          _reconnectWebSocket();
        }
      }
    }
  }

  void _reconnectWebSocket() {
    if (_token != null && _isConnectedToInternet) {
      _wsService.connect(_baseUrl, widget.groupId, _token!);
      _wsSubscription = _wsService.messageStream.listen((message) {
        _handleWebSocketMessage(message);
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _typingDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarPath = _groupAvatarPath ?? widget.groupAvatar;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 1,
        titleSpacing: 4,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupInfoPage(groupId: widget.groupId),
              ),
            );
          },
          child: Row(
            children: [
              _buildGroupAvatar(widget.groupName, avatarPath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _typingUsers.isNotEmpty
                            ? _getTypingText()
                            : '$_membersCount участников',
                        key: ValueKey(_typingUsers.isNotEmpty),
                        style: TextStyle(
                          fontSize: 12,
                          color: _typingUsers.isNotEmpty
                              ? Colors.green
                              : Colors.grey[600],
                          fontStyle: _typingUsers.isNotEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight: _typingUsers.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _wsService.isConnected &&
                                      _isConnectedToInternet
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _wsService.isConnected && _isConnectedToInternet
                              ? "Соединено"
                              : "Нет соединения",
                          style: TextStyle(
                            color:
                                _wsService.isConnected && _isConnectedToInternet
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Меню',
            onSelected: (value) {
              if (value == 'leave_group') {
                _leaveGroup();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'leave_group',
                child: Row(
                  children: [
                    const Icon(
                      Icons.exit_to_app,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Выйти из группы'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnectedToInternet)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.redAccent,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Нет подключения к интернету',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ошибка: $_error',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
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
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Нет сообщений',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Будьте первым, кто напишет!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _hasMoreMessages) {
                        return _isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox.shrink();
                      }

                      final message = _messages[index];
                      final isOwn = message['author_id'] == _currentUserId;
                      final showDate =
                          index == _messages.length - 1 ||
                          _shouldShowDateSeparator(index);

                      return Column(
                        children: [
                          _buildMessageBubble(message, isOwn),
                          if (showDate) _buildDateSeparator(message['sent_at']),
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
    if (index >= _messages.length - 1) return false;
    final current = DateTime.parse(_messages[index]['sent_at']).toLocal();
    final next = DateTime.parse(_messages[index + 1]['sent_at']).toLocal();
    return current.day != next.day ||
        current.month != next.month ||
        current.year != next.year;
  }

  Widget _buildDateSeparator(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    String text;

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
    final sentAt = DateTime.parse(message['sent_at']).toLocal();
    final timeStr = DateFormat('HH:mm').format(sentAt);
    final isEdited = message['edited_at'] != null;
    final authorName =
        message['author_name'] ?? message['author_username'] ?? 'Пользователь';
    final authorId = message['author_id'];

    String? filePath;
    String? fileName;
    int? fileSize;

    if (message['file'] != null && message['file'] is Map) {
      final fileData = message['file'] as Map<String, dynamic>;
      filePath = fileData['path'];
      fileName = fileData['name'] ?? 'Файл';
      fileSize = fileData['size'];
    }

    final hasFile =
        filePath != null && filePath.isNotEmpty && filePath != 'null';

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UsersProfileScreen(userId: authorId),
                  ),
                );
              },
              child: _buildUserAvatar(message),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isOwn
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.18)
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
                  crossAxisAlignment: isOwn
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isOwn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UsersProfileScreen(userId: authorId),
                              ),
                            );
                          },
                          child: Text(
                            authorName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    if (hasFile)
                      _buildFileAttachment(filePath, fileName!, fileSize),
                    if (content.isNotEmpty)
                      MessageContent(content: content, isOwn: isOwn),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEdited)
                          const Text(
                            'изменено ',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                print("Это вы");
              },
              child: _buildUserAvatar(message),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserAvatar(dynamic message) {
    final avatarPath =
        message['author_avatar'] ?? message['author_avatar_path'];
    final authorName =
        message['author_name'] ?? message['author_username'] ?? 'Пользователь';

    if (avatarPath != null && avatarPath.toString().isNotEmpty) {
      final url = _getFullUrl(avatarPath.toString());
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(url));
    }

    final firstLetter = authorName.isNotEmpty
        ? authorName[0].toUpperCase()
        : '?';
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];
    final color = colors[authorName.length % colors.length];

    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFileAttachment(
    String filePath,
    String fileName, [
    int? fileSize,
  ]) {
    final fileUrl = _getFullUrl(filePath);

    final isImage =
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.gif') ||
        fileName.toLowerCase().endsWith('.webp');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: isImage
            ? _buildImagePreview(filePath, fileName, fileSize)
            : _buildFilePreviewWidget(filePath, fileName, fileSize),
      ),
    );
  }

  Widget _buildImagePreview(String filePath, String fileName, [int? fileSize]) {
    final url = _getFullUrl(filePath);
    return GestureDetector(
      onTap: () => _showImageFullScreen(filePath),
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
                      Icon(
                        Icons.broken_image_rounded,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Не удалось загрузить',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
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
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  fileSize != null
                      ? '$fileName • ${_formatFileSize(fileSize)}'
                      : fileName,
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

  Widget _buildFilePreviewWidget(
    String filePath,
    String fileName, [
    int? fileSize,
  ]) {
    IconData fileIcon;
    Color iconColor;

    if (fileName.toLowerCase().endsWith('.pdf')) {
      fileIcon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.redAccent;
    } else if (fileName.toLowerCase().endsWith('.doc') ||
        fileName.toLowerCase().endsWith('.docx')) {
      fileIcon = Icons.description_rounded;
      iconColor = Colors.blueAccent;
    } else if (fileName.toLowerCase().endsWith('.mp4') ||
        fileName.toLowerCase().endsWith('.avi')) {
      fileIcon = Icons.video_file_rounded;
      iconColor = Colors.purpleAccent;
    } else if (fileName.toLowerCase().endsWith('.mp3') ||
        fileName.toLowerCase().endsWith('.wav')) {
      fileIcon = Icons.audio_file_rounded;
      iconColor = Colors.orangeAccent;
    } else {
      fileIcon = Icons.insert_drive_file_rounded;
      iconColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _downloadFile(filePath),
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileType(fileName, fileSize),
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

  String _formatFileType(String fileName, [int? fileSize]) {
    final extension = fileName.split('.').last.toLowerCase();
    String sizeStr = fileSize != null ? ' • ${_formatFileSize(fileSize)}' : '';

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return 'Изображение • ${extension.toUpperCase()}$sizeStr';
    } else if (['mp4', 'avi', 'mov'].contains(extension)) {
      return 'Видео • ${extension.toUpperCase()}$sizeStr';
    } else if (['mp3', 'wav', 'ogg'].contains(extension)) {
      return 'Аудио • ${extension.toUpperCase()}$sizeStr';
    } else if (extension == 'pdf') {
      return 'PDF документ$sizeStr';
    }
    return 'Файл • ${extension.toUpperCase()}$sizeStr';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
  }

  void _showImageFullScreen(String filePath) {
    final url = _getFullUrl(filePath);
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
                icon: const Icon(LucideIcons.arrowDownToLine),
                onPressed: () => _downloadFile(filePath),
              ),
              SizedBox(width: 5,)
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'Не удалось загрузить изображение',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile(String filePath) async {
    final url = _getFullUrl(filePath);
    final fileName = filePath.split('/').last;

    try {
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            _showSnackBar('Разрешение на управление хранилищем отклонено');
            return;
          }
        }
      }

      Directory? saveDirectory;
      if (Platform.isAndroid) {
        saveDirectory = Directory('/storage/emulated/0/Download');
        if (!await saveDirectory.exists()) {
          saveDirectory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        saveDirectory = await getApplicationDocumentsDirectory();
      } else {
        saveDirectory = await getApplicationDocumentsDirectory();
      }

      if (saveDirectory == null) {
        _showSnackBar('Не удалось получить директорию для сохранения');
        return;
      }

      final savePath = '${saveDirectory.path}/$fileName';
      final file = File(savePath);

      if (await file.exists()) {
        _showSnackBar('Файл уже скачан: $fileName');
        return;
      }

      final dio = Dio();
      final progressNotifier = ValueNotifier<double>(0.0);
      bool isCancelled = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Скачивание файла'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fileName, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<double>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, child) {
                        return Column(
                          children: [
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 8),
                            Text('${(progress * 100).toStringAsFixed(0)}%'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      isCancelled = true;
                      Navigator.pop(context);
                    },
                    child: const Text('Отмена'),
                  ),
                ],
              );
            },
          );
        },
      );

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progressNotifier.value = received / total;
          }
        },
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (isCancelled) {
        if (await file.exists()) await file.delete();
        _showSnackBar('Загрузка отменена');
      } else {
        _showSnackBar('Файл сохранен: $fileName');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Ошибка: $e');
      debugPrint('Download error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_selectedFile != null) _buildSelectedFilePreview(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _messageFocusNode,
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 6,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _isConnectedToInternet
                          ? 'Сообщение...'
                          : 'Нет интернета...',
                      hintStyle: TextStyle(
                        color: _isConnectedToInternet
                            ? Colors.grey[500]
                            : Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                      ),
                      isDense: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 2.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 2.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 2.0),
                      ),
                    ),
                    enabled: _isConnectedToInternet,
                  ),
                ),
                const SizedBox(width: 6),
                _buildCircleButton(
                  onTap: _pickFile,
                  child: Icon(
                    _selectedFile != null
                        ? LucideIcons.file
                        : LucideIcons.filePlusCorner,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),
                _buildCircleButton(
                  onTap: _isSending || !_isConnectedToInternet
                      ? null
                      : () => _sendMessage(),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          LucideIcons.sendHorizontal,
                          size: 20,
                          color: _isConnectedToInternet ? null : Colors.grey,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: onTap == null
              ? Colors.grey.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.3),
          width: 2.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildSelectedFilePreview() {
    final fileName = _selectedFile!.path.split('/').last;
    final extension = fileName.contains('.')
        ? '.${fileName.split('.').last}'
        : '';
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final fileSize = _selectedFile!.lengthSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
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
                  '${extension.toUpperCase()} • ${_formatFileSize(fileSize)}',
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
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.grey[600],
                ),
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
        backgroundImage: NetworkImage(_getFullUrl(avatarPath)),
      );
    }

    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final color = colors[name.length % colors.length];

    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

}