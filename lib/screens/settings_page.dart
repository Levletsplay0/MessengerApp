import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/providers/theme_provider.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '1.0.0';
  String _platform = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    String platform;
    if (Platform.isAndroid) {
      platform = 'Android';
    } else if (Platform.isIOS) {
      platform = 'iOS';
    } else if (Platform.isMacOS) {
      platform = 'macOS';
    } else if (Platform.isWindows) {
      platform = 'Windows';
    } else if (Platform.isLinux) {
      platform = 'Linux';
    } else {
      platform = 'Web';
    }

    setState(() {
      _appVersion = packageInfo.version;
      _platform = platform;
    });
  }

  Future<void> _showLogoutConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтверждение выхода'),
          content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    final api = ApiService();
    final response = await api.logout(token!);
    
    await prefs.remove('auth_token');

    if (!mounted) return;

    final isSuccess = response["success"];
    if (isSuccess == true){
      final message = response["message"];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.greenAccent,
        ),
      );
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLight = themeProvider.isLightMode;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              _buildSectionTitle('Внешний вид'),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Светлая тема'),
                        subtitle: Text(
                          isLight
                              ? 'Включена светлая тема'
                              : 'Включена тёмная тема',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        value: isLight,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                        },
                        secondary: Icon(
                          isLight ? LucideIcons.sun : LucideIcons.moon,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionTitle('О приложении'),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          LucideIcons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Версия приложения'),
                        subtitle: Text(_appVersion),
                      ),
                      const Divider(),

                      ListTile(
                        leading: Icon(
                          LucideIcons.monitorSmartphone,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Платформа'),
                        subtitle: Text(_platform),
                      ),
                      const Divider(),

                      ListTile(
                        leading: Icon(
                          LucideIcons.panelsTopLeft,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Frontend репозиторий'),
                        subtitle: const Text('GitHub'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _launchURL(
                          'https://github.com/Levletsplay0/MessengerApp',
                        ),
                      ),
                      const Divider(),

                      ListTile(
                        leading: Icon(
                          LucideIcons.server,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Backend репозиторий'),
                        subtitle: const Text('GitHub'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _launchURL(
                          'https://github.com/Levletsplay0/Messenger',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionTitle('Действия'),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          LucideIcons.eraser,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Очистить кэш'),
                        subtitle: const Text('Удалить временные файлы'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          await DefaultCacheManager().emptyCache();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Кэш очищен')),
                          );
                        },
                      ),
                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'Выйти из аккаунта',
                          style: TextStyle(color: Colors.red),
                        ),
                        subtitle: const Text('Полный выход из аккаунта'),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.red,
                        ),
                        onTap: _showLogoutConfirmation,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}
