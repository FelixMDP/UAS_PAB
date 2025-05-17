import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String userId;
  final String userName;
  final String imageUrl;
  final DateTime createdAt;
  final List<String> viewedBy;
  final Duration duration;
  
  Story({
    required this.id,
    required this.userId,
    required this.userName,
    required this.imageUrl,
    required this.createdAt,
    required this.viewedBy,
    this.duration = const Duration(seconds: 10),
  });

  factory Story.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewedBy': viewedBy,
    };
  }

  bool isViewed(String currentUserId) {
    return viewedBy.contains(currentUserId);
  }

  bool get isExpired {
    final now = DateTime.now();
    final expiryTime = createdAt.add(const Duration(hours: 24));
    return now.isAfter(expiryTime);
  }
}
