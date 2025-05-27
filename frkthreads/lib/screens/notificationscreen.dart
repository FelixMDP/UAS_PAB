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
    final backgroundColor =
        isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2);
    final textColor = isDark ? Colors.white : const Color(0xFF293133);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: Text('Notifications', style: TextStyle(color: textColor)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all, color: textColor),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: backgroundColor,
                      title: Text(
                        'Clear Notifications',
                        style: TextStyle(color: textColor),
                      ),
                      content: Text(
                        'Are you sure you want to clear all notifications?',
                        style: TextStyle(color: textColor),
                      ),
                      actions: [
                        TextButton(
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: textColor),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        TextButton(
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            NotificationService.instance
                                .clearAllNotifications();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('notifications')
                .where('toUserId', isEqualTo: currentUserId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: textColor));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(color: textColor.withOpacity(0.7)),
              ),
            );
          }

          // Group notifications by postId for likes
          Map<String, List<DocumentSnapshot>> groupedLikes = {};
          List<DocumentSnapshot> otherNotifications = [];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['type'] == 'like') {
              String postId = data['postId'];
              if (!groupedLikes.containsKey(postId)) {
                groupedLikes[postId] = [];
              }
              groupedLikes[postId]!.add(doc);
            } else {
              otherNotifications.add(doc);
            }
          }

          // Combine grouped likes with other notifications
          List<Widget> notificationWidgets = [];

          // Add grouped likes
          groupedLikes.forEach((postId, likes) {
            if (likes.isNotEmpty) {
              final latestLike = likes.first.data() as Map<String, dynamic>;
              final postDoc = FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId);

              notificationWidgets.add(
                FutureBuilder<DocumentSnapshot>(
                  future: postDoc.get(),
                  builder: (context, postSnapshot) {
                    if (!postSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final createdAtData = latestLike['createdAt'];
                    final createdAt =
                        (createdAtData is Timestamp)
                            ? createdAtData.toDate()
                            : (createdAtData is String)
                            ? DateTime.parse(createdAtData)
                            : DateTime.now();

                    return Dismissible(
                      key: Key('likes_$postId'),
                      onDismissed: (_) async {
                        for (var like in likes) {
                          await NotificationService.instance.deleteNotification(
                            like.id,
                          );
                        }
                      },
                      child: NotificationCard(
                        type: 'grouped_like',
                        fromUserName:
                            likes.length > 1
                                ? '${latestLike['fromUserName']} and ${likes.length - 1} others'
                                : latestLike['fromUserName'],
                        description: 'liked your post',
                        createdAt: createdAt,
                        isDark: isDark,
                        onTap: () async {
                          if (postSnapshot.hasData && context.mounted) {
                            final postData =
                                postSnapshot.data!.data()
                                    as Map<String, dynamic>?;
                            if (postData != null) {
                              final postCreatedAt = postData['createdAt'];
                              final DateTime parsedCreatedAt;
                              if (postCreatedAt is Timestamp) {
                                parsedCreatedAt = postCreatedAt.toDate();
                              } else if (postCreatedAt is String) {
                                parsedCreatedAt = DateTime.parse(postCreatedAt);
                              } else {
                                parsedCreatedAt = DateTime.now();
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => DetailScreen(
                                        imageBase64: postData['image'] ?? '',
                                        description:
                                            postData['description'] ?? '',
                                        createdAt: parsedCreatedAt,
                                        fullName:
                                            postData['fullName'] ?? 'Anonymous',
                                        latitude:
                                            (postData['latitude'] as num?)
                                                ?.toDouble() ??
                                            0.0,
                                        longitude:
                                            (postData['longitude'] as num?)
                                                ?.toDouble() ??
                                            0.0,
                                        category:
                                            postData['category'] ?? 'General',
                                        heroTag: 'notification_$postId',
                                        postId: postId,
                                        post: postSnapshot.data!,
                                      ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            }
          });

          // Add other notifications
          for (var doc in otherNotifications) {
            final data = doc.data() as Map<String, dynamic>;
            notificationWidgets.add(
              Dismissible(
                key: Key(doc.id),
                onDismissed: (_) {
                  NotificationService.instance.deleteNotification(doc.id);
                },
                child: NotificationCard(
                  type: data['type'],
                  fromUserName: data['fromUserName'],
                  description: data['description'],
                  createdAt:
                      (data['createdAt'] is Timestamp)
                          ? (data['createdAt'] as Timestamp).toDate()
                          : DateTime.now(),
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
                        final postCreatedAt = postData['createdAt'];
                        final DateTime parsedCreatedAt;
                        if (postCreatedAt is Timestamp) {
                          parsedCreatedAt = postCreatedAt.toDate();
                        } else if (postCreatedAt is String) {
                          parsedCreatedAt = DateTime.parse(postCreatedAt);
                        } else {
                          parsedCreatedAt = DateTime.now();
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => DetailScreen(
                                  imageBase64: postData['image'] ?? '',
                                  description: postData['description'] ?? '',
                                  createdAt: parsedCreatedAt,
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
                                  postId: data['postId'],
                                  post: postDoc,
                                ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            );
          }

          return ListView(children: notificationWidgets);
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
    final backgroundColor = isDark ? const Color(0xFF3D4A4D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF293133);

    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'like':
      case 'grouped_like':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        iconData = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Card(
      color: backgroundColor,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: textColor),
                        children: [
                          TextSpan(
                            text: fromUserName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' $description'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimeAgo(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat.yMMMd().format(dateTime);
    }
  }
}
