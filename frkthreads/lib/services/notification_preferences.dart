import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const String _likesKey = 'notification_likes';
  static const String _commentsKey = 'notification_comments';
  static const String _soundKey = 'notification_sound';
  static const String _vibrationKey = 'notification_vibration';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get likesEnabled => _prefs.getBool(_likesKey) ?? true;
  static bool get commentsEnabled => _prefs.getBool(_commentsKey) ?? true;
  static bool get soundEnabled => _prefs.getBool(_soundKey) ?? true;
  static bool get vibrationEnabled => _prefs.getBool(_vibrationKey) ?? true;

  static Future<void> setLikesEnabled(bool value) async {
    await _prefs.setBool(_likesKey, value);
  }

  static Future<void> setCommentsEnabled(bool value) async {
    await _prefs.setBool(_commentsKey, value);
  }

  static Future<void> setSoundEnabled(bool value) async {
    await _prefs.setBool(_soundKey, value);
  }

  static Future<void> setVibrationEnabled(bool value) async {
    await _prefs.setBool(_vibrationKey, value);
  }
}
