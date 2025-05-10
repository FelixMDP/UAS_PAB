import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  NotificationScreen({super.key});

  // Sample data for notifications
  final List<Map<String, String>> notifications = [
    {
      'title': 'New comment on your post',
      'description': 'Someone commented on your post "Flutter is awesome!"',
      'time': '5 minutes ago',
    },
    {
      'title': 'New follower',
      'description': 'John Doe started following you.',
      'time': '1 hour ago',
    },
    {
      'title': 'Post liked',
      'description': 'Your post "Learning Flutter" was liked by Jane Smith.',
      'time': '3 hours ago',
    },
    {
      'title': 'New message',
      'description': 'You have a new message from Alex.',
      'time': '1 day ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFFB88C66),
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return NotificationCard(
            title: notification['title']!,
            description: notification['description']!,
            time: notification['time']!,
          );
        },
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String title;
  final String description;
  final String time;

  const NotificationCard({
    super.key,
    required this.title,
    required this.description,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
