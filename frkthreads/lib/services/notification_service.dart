import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'local_notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  NotificationService._internal();

  Future<void> createNotification({
    required String type,
    required String toUserId,
    required String postId,
    required String description,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Don't create notification if user is notifying themselves
      if (currentUser.uid == toUserId) return;

      await _firestore.collection('notifications').add({
        'type': type,
        'fromUserId': currentUser.uid,
        'fromUserName': currentUser.displayName ?? 'Anonymous',
        'toUserId': toUserId,
        'postId': postId,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Show local notification based on type
      final username = currentUser.displayName ?? 'Someone';
      if (type == 'like') {
        await LocalNotificationService.instance.showLikeNotification(
          username: username,
          postId: postId,
        );
      } else if (type == 'comment') {
        await LocalNotificationService.instance.showCommentNotification(
          username: username,
          postId: postId,
        );
      }
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final notifications =
          await _firestore
              .collection('notifications')
              .where('toUserId', isEqualTo: currentUser.uid)
              .get();

      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  Stream<QuerySnapshot> getNotificationStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<int> getUnreadCount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final snapshot =
          await _firestore
              .collection('notifications')
              .where('toUserId', isEqualTo: currentUser.uid)
              .where('isRead', isEqualTo: false)
              .count()
              .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
}
