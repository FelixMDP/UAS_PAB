// detailscreen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Add constants at the top
const double _mapHeight = 400.0;
const double _imageHeight = 250.0;
const double _cornerRadius = 15.0;

class DetailScreen extends StatefulWidget {
  final String imageBase64;
  final String description;
  final DateTime createdAt;
  final String fullName;
  final double latitude;
  final double longitude;
  final String category;
  final String heroTag;
  final String postId;

  const DetailScreen({
    super.key,
    required this.imageBase64,
    required this.description,
    required this.createdAt,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.heroTag,
    required this.postId,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // Add state variables at the top
  final TextEditingController _commentController = TextEditingController();
  late final StreamSubscription<DocumentSnapshot> _postSubscription;
  List<String> comments = [];
  int likes = 0;
  bool isLiked = false;
  Timer? _timer;
  String _timeAgo = '';
  bool isPostOwner = false;

  @override
  void initState() {
    super.initState();
    _postSubscription = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            final data = doc.data()!;
            setState(() {
              comments = List<String>.from(data['comments'] ?? []);
              likes = data['likes'] ?? 0;
              isLiked = (data['likedBy'] ?? []).contains(
                FirebaseAuth.instance.currentUser?.uid,
              );
            });
          }
        });

    _updateTimeAgo();
    _checkPostOwnership();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTimeAgo();
    });
  }

  void _updateTimeAgo() {
    setState(() {
      _timeAgo = _formatTimeAgo(widget.createdAt);
    });
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    }
  }

  Future<void> _fetchPostDetails() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          comments = List<String>.from(data['comments'] ?? []);
          likes = data['likes'] ?? 0;
          isLiked = (data['likedBy'] ?? []).contains(
            FirebaseAuth.instance.currentUser?.uid,
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching post details: $e');
    }
  }

  Future<void> _toggleLike() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      final doc = await postRef.get();

      if (!doc.exists) return;

      final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);

      if (likedBy.contains(uid)) {
        likedBy.remove(uid);
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': likedBy,
        });
      } else {
        likedBy.add(uid);
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': likedBy,
        });
      }

      // Add notification
      final postData = doc.data() as Map<String, dynamic>;
      final postOwnerId = postData['userId'];

      if (postOwnerId != FirebaseAuth.instance.currentUser?.uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'like',
          'fromUserId': FirebaseAuth.instance.currentUser?.uid,
          'fromUserName':
              FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous',
          'toUserId': postOwnerId,
          'postId': widget.postId,
          'description': 'liked your post',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      _fetchPostDetails();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
            'comments': FieldValue.arrayUnion([_commentController.text.trim()]),
          });

      // Add notification
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      final doc = await postRef.get();
      final postData = doc.data() as Map<String, dynamic>;
      final postOwnerId = postData['userId'];

      if (postOwnerId != FirebaseAuth.instance.currentUser?.uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'comment',
          'fromUserId': FirebaseAuth.instance.currentUser?.uid,
          'fromUserName':
              FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous',
          'toUserId': postOwnerId,
          'postId': widget.postId,
          'description':
              'commented on your post: ${_commentController.text.trim()}',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      _commentController.clear();
      _fetchPostDetails();
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  Future<void> openMap(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
    );
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka Google Maps')),
      );
    }
  }

  void _showMapBottomSheet() {
    if (widget.latitude == 0.0 || widget.longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available for this post')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Post Location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(widget.latitude, widget.longitude),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('postLocation'),
                          position: LatLng(widget.latitude, widget.longitude),
                          infoWindow: InfoWindow(title: widget.fullName),
                        ),
                      },
                      mapType: MapType.normal,
                      zoomControlsEnabled: true,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      compassEnabled: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Posted by ${widget.fullName}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat(
                              'dd MMMM yyyy, HH:mm',
                            ).format(widget.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      onPressed: () => _openInGoogleMaps(),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  Future<void> _checkPostOwnership() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final doc =
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .get();

    if (doc.exists && mounted) {
      setState(() {
        isPostOwner = doc.data()?['userId'] == currentUserId;
      });
    }
  }

  Future<void> _deletePost() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();

      if (mounted) {
        Navigator.pop(context); // Return to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePost();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(comments[index], style: TextStyle(fontSize: 14)),
                leading: CircleAvatar(child: Icon(Icons.person)),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.all(8),
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
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _addComment(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAtFormatted = DateFormat(
      'dd MMMM yyyy, HH:mm',
    ).format(widget.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(_timeAgo),
        actions: [
          if (isPostOwner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap:
                  () =>
                      widget.latitude != 0.0 && widget.longitude != 0.0
                          ? _showMapBottomSheet()
                          : null,
              child: Stack(
                children: [
                  Hero(
                    tag: widget.heroTag,
                    child: Image.memory(
                      base64Decode(widget.imageBase64),
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (widget.latitude != 0.0 && widget.longitude != 0.0)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'View Location',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category, size: 20, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        widget.category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => openMap(context),
                        icon: const Icon(
                          Icons.map,
                          size: 32,
                          color: Colors.lightGreen,
                        ),
                        tooltip: "Buka di Google Maps",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 20,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        createdAtFormatted,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
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
                      IconButton(
                        icon: const Icon(Icons.comment),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder:
                                (context) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Comments (${comments.length})',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildCommentSection(),
                                      ],
                                    ),
                                  ),
                                ),
                          );
                        },
                      ),
                      Text('${comments.length} comments'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _timer?.cancel();
    _postSubscription.cancel();
    super.dispose();
  }
}
