import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get storiesRef => _firestore.collection('stories');

  // Add a new story
  Future<String> addStory({required String imageUrl, String? userName}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final story = Story(
        id: '', // Will be set by Firestore
        userId: user.uid,
        userName: userName ?? user.displayName ?? 'Anonymous',
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        viewedBy: [],
      );

      final docRef = await storiesRef.add(story.toMap());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get all active stories (not expired, within 24 hours)
  Stream<List<Story>> getActiveStories() {
    final twentyFourHoursAgo = DateTime.now().subtract(
      const Duration(hours: 24),
    );

    return storiesRef
        .where('createdAt', isGreaterThan: twentyFourHoursAgo)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();
        });
  }

  // Get stories for a specific user
  Stream<List<Story>> getUserStories(String userId) {
    final twentyFourHoursAgo = DateTime.now().subtract(
      const Duration(hours: 24),
    );

    return storiesRef
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThan: twentyFourHoursAgo)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();
        });
  }

  // Mark a story as viewed
  Future<void> markStoryAsViewed(String storyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      await storiesRef.doc(storyId).update({
        'viewedBy': FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Delete a story
  Future<void> deleteStory(String storyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Optional: Check if the user owns the story before deleting
      final storyDoc = await storiesRef.doc(storyId).get();
      final storyData = storyDoc.data() as Map<String, dynamic>?;

      if (storyData == null) throw 'Story not found';
      if (storyData['userId'] != user.uid)
        throw 'Not authorized to delete this story';

      await storiesRef.doc(storyId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Delete expired stories (optional, can be run periodically)
  Future<void> deleteExpiredStories() async {
    try {
      final twentyFourHoursAgo = DateTime.now().subtract(
        const Duration(hours: 24),
      );
      final expiredStories =
          await storiesRef
              .where('createdAt', isLessThan: twentyFourHoursAgo)
              .get();

      final batch = _firestore.batch();
      for (var doc in expiredStories.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
