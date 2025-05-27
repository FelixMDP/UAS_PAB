import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String userId;
  final String userName;
  final String? imageBase64;
  final Timestamp createdAt;
  final List<String> viewedBy;
  final Duration duration;

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    this.imageBase64,
    required this.createdAt,
    required this.viewedBy,
    required this.duration,
  });

  factory Story.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      imageBase64: data['imageBase64'] as String?, // Ambil imageBase64
      createdAt: data['createdAt'] ?? Timestamp.now(),
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
      duration: Duration(seconds: (data['durationInSeconds'] ?? 5) as int),
    );
  }

  // Metode isViewed Anda (Anda sepertinya sudah punya ini)
  bool isViewed(String currentUserId) {
    return viewedBy.contains(currentUserId);
  }
}