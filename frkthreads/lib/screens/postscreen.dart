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
          _showError('Post not found');
          Navigator.pop(context);
        }
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final data = doc.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final commentDetails = List<Map<String, dynamic>>.from(
        data['commentDetails'] ?? [],
      );

      setState(() {
        post = doc;
        isLoading = false;
        isLiked = uid != null && likedBy.contains(uid);
      });
    } catch (e) {
      debugPrint('Error fetching post: $e');
      if (mounted) {
        _showError('Error loading post');
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
    if (isSubmittingComment || comment.trim().isEmpty) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showError('Please sign in to comment');
        return;
      }

      setState(() => isSubmittingComment = true);

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
            'commentDetails': FieldValue.arrayUnion([commentData]),
          });

      _commentController.clear();
      _fetchPost();
    } catch (e) {
      _showError('Error adding comment: $e');
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

  Widget _buildInteractionButtons(Map<String, dynamic> data) {
    final likes = data['likes'] ?? 0;
    final comments = List<String>.from(data['comments'] ?? []);
    final isLiked = (data['likedBy'] ?? []).contains(
      FirebaseAuth.instance.currentUser?.uid,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : null,
          ),
          onPressed: _toggleLike,
        ),
        Text('$likes'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.comment_outlined),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder:
                  (context) => _buildCommentsSheet(
                    comments.cast<Map<String, dynamic>>(),
                  ),
            );
          },
        ),
        Text('${comments.length}'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.location_on),
          onPressed: () => _showLocationMap(data),
        ),
      ],
    );
  }

  void _showLocationMap(Map<String, dynamic> data) {
    final latitude = data['latitude'] as double?;
    final longitude = data['longitude'] as double?;

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location not available')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            height: 300,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(latitude, longitude),
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('postLocation'),
                  position: LatLng(latitude, longitude),
                ),
              },
            ),
          ),
    );
  }

  Widget _buildCommentsSheet(List<Map<String, dynamic>> commentDetails) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Comments (${commentDetails.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: commentDetails.length,
              itemBuilder: (context, index) {
                final comment = commentDetails[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(comment['userName'] ?? 'Anonymous'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment['text']),
                      Text(
                        _formatTime(DateTime.parse(comment['createdAt'])),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      isSubmittingComment
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                  onPressed:
                      isSubmittingComment
                          ? null
                          : () => _addComment(_commentController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
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
      final commentDetails = List<Map<String, dynamic>>.from(
        data['commentDetails'] ?? [],
      );

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
              child: _buildInteractionButtons(data),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Comments (${commentDetails.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder:
                                (context) =>
                                    _buildCommentsSheet(commentDetails),
                          );
                        },
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  // Show latest 2 comments
                  ...commentDetails
                      .take(2)
                      .map(
                        (comment) => ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(comment['userName'] ?? 'Anonymous'),
                          subtitle: Text(comment['text']),
                        ),
                      ),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addComment,
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

class CommentTile extends StatelessWidget {
  final String userName;
  final String text;
  final DateTime createdAt;

  const CommentTile({
    required this.userName,
    required this.text,
    required this.createdAt,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(userName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          Text(
            _formatTimeAgo(createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
