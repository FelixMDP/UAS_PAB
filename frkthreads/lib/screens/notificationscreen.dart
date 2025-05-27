import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frkthreads/screens/postdetailscreen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/services/notification_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
        body: Center(
          child: Text(
            'Please sign in to view notifications',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFB88C66),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Clear Notifications'),
                      content: const Text(
                        'Are you sure you want to clear all notifications?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            NotificationService.instance
                                .clearAllNotifications();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationService.instance.getNotificationStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(
                  isDark ? Colors.white : Colors.black87,
                ),
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              final createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final type = data['type'] as String? ?? 'general';
              final fromUserName = data['fromUserName'] as String? ?? 'Someone';
              String description = data['description'] as String? ?? '';

              // Mark notification as read when viewed
              if (!(data['isRead'] as bool? ?? false)) {
                NotificationService.instance.markNotificationAsRead(
                  notification.id,
                );
              }

              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  NotificationService.instance.deleteNotification(
                    notification.id,
                  );
                },
                child: NotificationCard(
                  type: type,
                  fromUserName: fromUserName,
                  description: description,
                  createdAt: createdAt,
                  isDark: isDark,
                  onTap: () async {
                    if (data['postId'] != null) {
                      final postDoc =
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(data['postId'])
                              .get();

                      if (postDoc.exists && context.mounted) {
                        final postData = postDoc.data()!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => DetailScreen(
                                  postId: data['postId'],
                                  imageBase64: postData['image'] ?? '',
                                  description: postData['description'] ?? '',
                                  createdAt:
                                      (postData['createdAt'] as Timestamp)
                                          .toDate(),
                                  fullName: postData['fullName'] ?? 'Anonymous',
                                  latitude:
                                      (postData['latitude'] as num?)
                                          ?.toDouble() ??
                                      0.0,
                                  longitude:
                                      (postData['longitude'] as num?)
                                          ?.toDouble() ??
                                      0.0,
                                  category: postData['category'] ?? 'General',
                                  heroTag: 'notification_${data['postId']}',
                                  post: postDoc,
                                ),
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String type;
  final String fromUserName;
  final String description;
  final DateTime createdAt;
  final bool isDark;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.type,
    required this.fromUserName,
    required this.description,
    required this.createdAt,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    switch (type) {
      case 'like':
        icon = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        icon = Icons.comment;
        iconColor = Colors.blue;
        break;
      default:
        icon = Icons.notifications;
        iconColor = isDark ? Colors.white70 : Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isDark ? Colors.grey[850] : Colors.white,
      elevation: 2,
      shadowColor: isDark ? Colors.black26 : Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          '$fromUserName $description',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          _formatTimeAgo(createdAt),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey[600],
            fontSize: 13,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}
