import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story.dart'; // Pastikan model Story Anda sudah diperbarui

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get storiesRef => _firestore.collection('stories');

  // Add a new story
  // Mengubah parameter dan data yang disimpan
  Future<String> addStory({
    required String imageBase64, // Diubah dari imageUrl
    String? userName,
    int durationInSeconds = 5, // Tambahkan durasi, default 5 detik
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Membuat map data secara langsung untuk disimpan ke Firestore
      // Ini mirip dengan yang dilakukan di add_story_screen.dart
      // dan menghindari pembuatan objek Story hanya untuk .toMap()
      final storyData = {
        'userId': user.uid,
        'userName': userName ?? user.displayName ?? 'Anonymous',
        'imageBase64': imageBase64, // Menggunakan imageBase64
        'createdAt': Timestamp.now(), // Menggunakan Timestamp.now()
        'viewedBy': [],
        'durationInSeconds': durationInSeconds, // Menyimpan durasi dalam detik
      };

      final docRef = await storiesRef.add(storyData);
      return docRef.id;
    } catch (e) {
      // print('Error adding story: $e'); // Untuk debugging
      rethrow;
    }
  }

  // Get all active stories (not expired, within 24 hours)
  Stream<List<Story>> getActiveStories() {
    // Menggunakan Timestamp.fromDate untuk query yang lebih presisi
    final twentyFourHoursAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
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
    // Menggunakan Timestamp.fromDate untuk query
    final twentyFourHoursAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
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
      // print('Error marking story as viewed: $e'); // Untuk debugging
      rethrow;
    }
  }

  // Delete a story
  Future<void> deleteStory(String storyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final storyDoc = await storiesRef.doc(storyId).get();
      final storyData = storyDoc.data() as Map<String, dynamic>?;

      if (storyData == null) throw 'Story not found';
      // Pastikan otorisasi sebelum menghapus
      if (storyData['userId'] != user.uid) {
        throw 'Not authorized to delete this story';
      }
      // Anda mungkin ingin menambahkan logika untuk menghapus gambar dari Firebase Storage jika Anda menggunakannya nanti
      // Untuk sekarang karena base64, hanya perlu hapus dokumen Firestore.

      await storiesRef.doc(storyId).delete();
    } catch (e) {
      // print('Error deleting story: $e'); // Untuk debugging
      rethrow;
    }
  }

  // Delete expired stories (optional, can be run periodically)
  Future<void> deleteExpiredStories() async {
    try {
      // Menggunakan Timestamp.fromDate untuk query
      final twentyFourHoursAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      final expiredStories = await storiesRef
          .where('createdAt', isLessThan: twentyFourHoursAgo)
          .get();

      final batch = _firestore.batch();
      for (var doc in expiredStories.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      // print('${expiredStories.docs.length} expired stories deleted.'); // Untuk info
    } catch (e) {
      // print('Error deleting expired stories: $e'); // Untuk debugging
      rethrow;
    }
  }
}