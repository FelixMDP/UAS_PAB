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

  // Create a Story instance from Firestore document
  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
      duration: const Duration(seconds: 10),
    );
  }

  // Convert Story instance to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewedBy': viewedBy,
    };
  }

  // Check if a user has viewed this story
  bool isViewed(String currentUserId) {
    return viewedBy.contains(currentUserId);
  }

  // Check if the story has expired (older than 24 hours)
  bool get isExpired {
    final now = DateTime.now();
    final expiryTime = createdAt.add(const Duration(hours: 24));
    return now.isAfter(expiryTime);
  }

  // Create a copy of Story with updated fields
  Story copyWith({
    String? id,
    String? userId,
    String? userName,
    String? imageUrl,
    DateTime? createdAt,
    List<String>? viewedBy,
    Duration? duration,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      viewedBy: viewedBy ?? this.viewedBy,
      duration: duration ?? this.duration,
    );
  }
}
