// detailscreen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frkthreads/widgets/post_ui_components.dart';
import 'package:frkthreads/services/notification_service.dart';

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
    required this.postId, required DocumentSnapshot<Object?> post,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // Add state variables at the top
  final TextEditingController _commentController = TextEditingController();
  late final StreamSubscription<DocumentSnapshot> _postSubscription;
  List<String> comments = [];
  List<Map<String, dynamic>> commentDetails = [];
  int likes = 0;
  bool isLiked = false;
  Timer? _timer;
  String _timeAgo = '';
  bool isPostOwner = false;
  bool _isLiking = false;
  bool _isCommenting = false;

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
              commentDetails = List<Map<String, dynamic>>.from(
                data['commentDetails'] ?? [],
              );
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
    if (_isLiking) return;

    try {
      setState(() => _isLiking = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      final doc = await postRef.get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? []);

      if (likedBy.contains(uid)) {
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
        });
        setState(() {
          isLiked = false;
          likes--;
        });
      } else {
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([uid]),
        });
        setState(() {
          isLiked = true;
          likes++;
        }); // Add notification
        final postOwnerId = data['userId'];
        if (postOwnerId != uid) {
          await NotificationService.instance.createNotification(
            type: 'like',
            toUserId: postOwnerId,
            postId: widget.postId,
            description: 'liked your post',
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating like: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (_isCommenting || commentText.isEmpty) return;

    try {
      setState(() => _isCommenting = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Anonymous';

      final commentData = {
        'text': commentText,
        'userId': uid,
        'userName': userName,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
            'comments': FieldValue.arrayUnion([commentText]),
            'commentDetails': FieldValue.arrayUnion([commentData]),
          }); // Add notification
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      final doc = await postRef.get();
      final postData = doc.data() as Map<String, dynamic>;
      final postOwnerId = postData['userId'];
      if (postOwnerId != uid) {
        await NotificationService.instance.createNotification(
          type: 'comment',
          toUserId: postOwnerId,
          postId: widget.postId,
          description: 'commented on your post: $commentText',
        );
      }

      _commentController.clear();
      _fetchPostDetails();
    } catch (e) {
      debugPrint('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCommenting = false);
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
              onPressed: () async {
                Navigator.pop(context);
                await _deletePost();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder:
          (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with comment count
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: commentDetails.length),
                        duration: const Duration(milliseconds: 500),
                        builder:
                            (context, value, child) => Text(
                              'Comments ($value)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                      const Spacer(),
                      if (commentDetails.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.sort),
                          label: const Text('Latest'),
                          onPressed: () {
                            // Implement sorting if needed
                          },
                        ),
                    ],
                  ),
                ),
                // Comments list
                Expanded(
                  child:
                      commentDetails.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet\nBe the first to comment!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            controller: controller,
                            itemCount: commentDetails.length,
                            itemBuilder: (context, index) {
                              final comment = commentDetails[index];
                              final commentTime = DateTime.parse(
                                comment['createdAt'],
                              );
                              final timeAgo = _formatTimeAgo(commentTime);

                              return Column(
                                children: [
                                  ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            comment['userName'] ?? 'Anonymous',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeAgo,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        comment['text'],
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (index < commentDetails.length - 1)
                                    const Divider(indent: 72),
                                ],
                              );
                            },
                          ),
                ),
                // Comment input
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            fillColor: Colors.grey[100],
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.blue,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          icon:
                              _isCommenting
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(Icons.send, color: Colors.white),
                          onPressed: _isCommenting ? null : _addComment,
                        ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fullName,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _timeAgo,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (isPostOwner)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.black87),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: widget.heroTag,
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  image: DecorationImage(
                    image: MemoryImage(base64Decode(widget.imageBase64)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      AnimatedLikeButton(
                        isLiked: isLiked,
                        isLoading: _isLiking,
                        likes: likes,
                        onTap: _toggleLike,
                      ),
                      const SizedBox(width: 16),
                      CommentButton(
                        commentCount: comments.length,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => _buildCommentsSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Location card
            if (widget.latitude != 0 && widget.longitude != 0)
              Card(
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () => _showMapBottomSheet(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'View Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
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
