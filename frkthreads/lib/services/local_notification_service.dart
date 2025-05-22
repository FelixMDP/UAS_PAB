import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
// This is needed for Android 13 and above
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._();
  static LocalNotificationService get instance => _instance;

  final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _notificationStreamController = StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get onNotificationTap => _notificationStreamController.stream;

  LocalNotificationService._();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentSound: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );    // Request permissions for Android
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      debugPrint('Notification permissions requested');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final payloadParts = response.payload!.split(',');
      if (payloadParts.length == 2) {
        _notificationStreamController.add({
          'type': payloadParts[0],
          'postId': payloadParts[1],
        });
      }
    }
  }

  Future<bool> _checkPermissions() async {
    if (Theme.of(GlobalObjectKey(this).currentContext!).platform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true; // iOS permissions are handled during initialization
  }

  Future<bool> requestPermissions() async {
    if (Theme.of(GlobalObjectKey(this).currentContext!).platform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> showLikeNotification({
    required String username,
    required String postId,
  }) async {
    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        debugPrint('Notification permissions not granted');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        'likes_channel',
        'Post Likes',
        channelDescription: 'Notifications for post likes',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        color: const Color.fromARGB(255, 33, 150, 243),
        ledColor: const Color.fromARGB(255, 33, 150, 243),
        ledOnMs: 1000,
        ledOffMs: 500,
        category: AndroidNotificationCategory.social,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use a unique ID based on timestamp and a random factor
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await _notificationsPlugin.show(
        notificationId,
        'New Like',
        '$username liked your post',
        details,
        payload: 'like,$postId',
      );
    } catch (e) {
      debugPrint('Error showing like notification: $e');
    }
  }

  Future<void> showCommentNotification({
    required String username,
    required String postId,
  }) async {
    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        debugPrint('Notification permissions not granted');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        'comments_channel',
        'Post Comments',
        channelDescription: 'Notifications for post comments',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        color: const Color.fromARGB(255, 76, 175, 80),
        ledColor: const Color.fromARGB(255, 76, 175, 80),
        ledOnMs: 1000,
        ledOffMs: 500,
        category: AndroidNotificationCategory.social,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use a unique ID based on timestamp and a random factor
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await _notificationsPlugin.show(
        notificationId,
        'New Comment',
        '$username commented on your post',
        details,
        payload: 'comment,$postId',
      );
    } catch (e) {
      debugPrint('Error showing comment notification: $e');
    }
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
