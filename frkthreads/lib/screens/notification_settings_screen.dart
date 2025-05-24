import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/services/notification_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _likesEnabled = NotificationPreferences.likesEnabled;
      _commentsEnabled = NotificationPreferences.commentsEnabled;
      _soundEnabled = NotificationPreferences.soundEnabled;
      _vibrationEnabled = NotificationPreferences.vibrationEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFB88C66),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Notification Types',
            children: [
              SwitchListTile(
                title: const Text('Likes'),
                subtitle: const Text('Notify when someone likes your post'),
                value: _likesEnabled,
                onChanged: (value) {
                  setState(() => _likesEnabled = value);
                  NotificationPreferences.setLikesEnabled(value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Comments'),
                subtitle: const Text(
                  'Notify when someone comments on your post',
                ),
                value: _commentsEnabled,
                onChanged: (value) {
                  setState(() => _commentsEnabled = value);
                  NotificationPreferences.setCommentsEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Notification Settings',
            children: [
              SwitchListTile(
                title: const Text('Sound'),
                subtitle: const Text('Play sound for notifications'),
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() => _soundEnabled = value);
                  NotificationPreferences.setSoundEnabled(value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Vibration'),
                subtitle: const Text('Vibrate for notifications'),
                value: _vibrationEnabled,
                onChanged: (value) {
                  setState(() => _vibrationEnabled = value);
                  NotificationPreferences.setVibrationEnabled(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: isDark ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
