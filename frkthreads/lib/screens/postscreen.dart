import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class PostScreen extends StatefulWidget {
  final String postId;

  const PostScreen({super.key, required this.postId});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late DocumentSnapshot post;
  bool isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  BitmapDescriptor? customMarker;
  double? _latitude;
  double? _longitude;
  bool isLiked = false; // Tambahkan variabel isLiked
  bool isSubmittingComment = false;
  bool isSubmittingLike = false;

  @override
  void initState() {
    super.initState();
    _getLocation(); // Get location when screen loads
    _fetchPost();
    _createCustomMarker();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions permanently denied. Please enable in settings.',
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  Future<void> _fetchPost() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Post not found')));
          Navigator.pop(context);
        }
        return;
      }

      // Get current user ID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final data = doc.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? []);

      setState(() {
        post = doc;
        isLoading = false;
        isLiked =
            uid != null &&
            likedBy.contains(uid); // Set status like berdasarkan array likedBy
      });
    } catch (e) {
      debugPrint('Error fetching post: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading post')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _createCustomMarker() async {
    customMarker = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/location_marker.png',
    );
  }

  Future<void> _toggleLike() async {
    if (isSubmittingLike) return; // Prevent double tap
    setState(() => isSubmittingLike = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      final doc = await postRef.get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final isLiked = likedBy.contains(uid);

      if (isLiked) {
        // Unlike
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
        });
      } else {
        // Like
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([uid]),
        });
      }

      _fetchPost(); // Refresh post data
    } catch (e) {
      debugPrint('Error toggling like: $e');
    } finally {
      if (mounted) setState(() => isSubmittingLike = false);
    }
  }

  Future<void> _addComment(String comment) async {
    if (isSubmittingComment) return;
    setState(() => isSubmittingComment = true);
    try {
      if (comment.trim().isEmpty) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Get user's name
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Anonymous';

      final commentData = {
        'text': comment.trim(),
        'userId': uid,
        'userName': userName,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
            'comments': FieldValue.arrayUnion([comment.trim()]),
            'commentDetails': FieldValue.arrayUnion([commentData]),
          });

      _commentController.clear();
      _fetchPost();
    } catch (e) {
      debugPrint('Error adding comment: $e');
    } finally {
      if (mounted) setState(() => isSubmittingComment = false);
    }
  }

  void _toggleSave() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final data = post.data() as Map<String, dynamic>?;
      final savedBy = List<String>.from(data?['savedBy'] ?? []);

      if (savedBy.contains(uid)) {
        savedBy.remove(uid);
      } else {
        savedBy.add(uid);
      }

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'savedBy': savedBy});

      _fetchPost();
    } catch (e) {
      debugPrint('Error toggling save: $e');
    }
  }

  Widget _buildLocationSection(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Icon(Icons.location_off),
                SizedBox(width: 8),
                Text('Location not available'),
              ],
            ),
          ),
        ),
      );
    }

    try {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('postLocation'),
                    position: LatLng(latitude, longitude),
                    icon: customMarker ?? BitmapDescriptor.defaultMarker,
                    infoWindow: const InfoWindow(title: 'Post Location'),
                  ),
                },
                mapType: MapType.normal,
                zoomControlsEnabled: true,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: _getLocation,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building map: $e');
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Error loading map'),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    try {
      final data = post.data() as Map<String, dynamic>?;
      if (data == null) {
        return const Center(child: Text('Post not found'));
      }

      final imageBase64 = data['image'] as String?;
      final description = data['description'] as String?;
      final latitude = data['latitude'] as double?;
      final longitude = data['longitude'] as double?;
      final likes = data['likes'] as int? ?? 0;
      final comments = List<String>.from(data['comments'] ?? []);
      final fullName = data['fullName'] as String? ?? 'Anonymous';

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageBase64 != null)
              Image.memory(
                base64Decode(imageBase64),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading image: $error');
                  return const Center(
                    child: Icon(Icons.error_outline, size: 50),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(description ?? '', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            if (latitude != null && longitude != null)
              _buildLocationSection(latitude, longitude),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : null,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text('$likes likes'),
                      const SizedBox(width: 16),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark),
                    onPressed: _toggleSave,
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...comments.map(
                    (comment) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('- $comment'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed:
                            () => _addComment(_commentController.text.trim()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error building post screen: $e');
      return Center(child: Text('Error loading post: $e'));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
