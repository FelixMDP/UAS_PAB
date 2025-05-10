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
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
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

      setState(() {
        post = doc;
        isLoading = false;
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

  void _toggleLike() async {
    try {
      final data = post.data() as Map<String, dynamic>?;
      final currentLikes = data?['likes'] as int? ?? 0;

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'likes': currentLikes + 1});
      _fetchPost();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  void _addComment(String comment) async {
    if (comment.trim().isEmpty) return;
    try {
      final data = post.data() as Map<String, dynamic>?;
      final comments = List<String>.from(data?['comments'] ?? []);
      comments.add(comment);

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'comments': comments});
      _commentController.clear();
      _fetchPost();
    } catch (e) {
      debugPrint('Error adding comment: $e');
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
      return const SizedBox.shrink();
    }

    try {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(latitude, longitude),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('postLocation'),
                position: LatLng(latitude, longitude),
                icon: customMarker ?? BitmapDescriptor.defaultMarker,
                infoWindow: InfoWindow(
                  title: 'Posted from here',
                  snippet: '$latitude, $longitude',
                ),
              ),
            },
            mapType: MapType.normal,
            zoomControlsEnabled: true,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building map: $e');
      return const SizedBox.shrink();
    }
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
                        icon: const Icon(Icons.thumb_up),
                        onPressed: _toggleLike,
                      ),
                      Text('$likes likes'),
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
