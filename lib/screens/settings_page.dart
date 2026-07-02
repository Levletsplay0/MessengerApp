import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _islight = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 50),
        Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: 300,
                    child: SwitchListTile(
                      title: Text("Сменить тему"),
                      value: _islight, 
                      onChanged: (value) {
                        setState(() {
                          _islight = value;
                        });
                      }
                    ),
                  ),
                  const Divider(),
                  SizedBox(
                    width: 300,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: (){}, 
                      child: const Text("Очистить кэш")
                    ),
                  ),
                  const Divider(),
                  SizedBox(
                    width: 300,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: (){}, 
                      child: const Text("data")
                    ),
                  ),    
                ]
              ),
            ),
          ),
        )
      ],
    );
  }
}