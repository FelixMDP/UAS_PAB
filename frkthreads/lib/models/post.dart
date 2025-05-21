import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String description;
  final String fullName;
  final DateTime createdAt;
  final String? image;
  final double latitude;
  final double longitude;
  final String category;
  final List<String> comments;
  final int likes;
  final List<String> likedBy;

  Post({
    required this.id,
    required this.userId,
    required this.description,
    required this.fullName,
    required this.createdAt,
    this.image,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.comments,
    required this.likes,
    required this.likedBy,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      description: data['description'] ?? '',
      fullName: data['fullName'] ?? 'Anonymous',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      image: data['image'],
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      category: data['category'] ?? 'Uncategorized',
      comments: List<String>.from(data['comments'] ?? []),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'description': description,
      'fullName': fullName,
      'createdAt': Timestamp.fromDate(createdAt),
      'image': image,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'comments': comments,
      'likes': likes,
      'likedBy': likedBy,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? description,
    String? fullName,
    DateTime? createdAt,
    String? image,
    double? latitude,
    double? longitude,
    String? category,
    List<String>? comments,
    int? likes,
    List<String>? likedBy,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      comments: comments ?? this.comments,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}
