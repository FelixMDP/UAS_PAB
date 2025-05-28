import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  static LocalNotificationService get instance => _instance;

  final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _notificationStreamController =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get onNotificationTap =>
      _notificationStreamController.stream;
  LocalNotificationService._();

  Future<void> initialize() async {
    try {
      // Request notification permissions first
      await requestPermissions();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
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
      );

      // Create notification channels for Android
      if (_getPlatform() == TargetPlatform.android) {
        await _createNotificationChannels();
      }

      debugPrint('LocalNotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    final likesChannel = AndroidNotificationChannel(
      'likes_channel',
      'Post Likes',
      description: 'Notifications for post likes',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      ledColor: const Color.fromARGB(255, 33, 150, 243),
      sound: const RawResourceAndroidNotificationSound('notify'),
    );

    final commentsChannel = AndroidNotificationChannel(
      'comments_channel',
      'Post Comments',
      description: 'Notifications for post comments',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      ledColor: const Color.fromARGB(255, 76, 175, 80),
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(likesChannel);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(commentsChannel);
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
    if (_getPlatform() == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        debugPrint(
          'Notification permissions not granted. Current status: ${status.name}',
        );
        return false;
      }
    }
    return true;
  }

  Future<bool> requestPermissions() async {
    if (_getPlatform() == TargetPlatform.android) {
      final status = await Permission.notification.request();
      debugPrint('Notification permission request result: ${status.name}');
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
        sound: const RawResourceAndroidNotificationSound('notify'),
        icon: '@mipmap/ic_launcher',
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
        sound: const RawResourceAndroidNotificationSound('notify'),
        icon: '@mipmap/ic_launcher',
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

  TargetPlatform _getPlatform() {
    if (Platform.isAndroid) return TargetPlatform.android;
    if (Platform.isIOS) return TargetPlatform.iOS;
    return TargetPlatform.android; // Default to Android
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
