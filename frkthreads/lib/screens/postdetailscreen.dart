// detailscreen.dart

import 'dart:convert';
import 'dart:ui';
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
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';

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
  final DocumentSnapshot post;
    // Color palette for consistency across app
  static const Color _darkBackground = Color(0xFF2D3B3A);
  static const Color _lightBackground = Color(0xFFF1E9D2);
  static const Color _accent = Color(0xFFB88C66);

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
<<<<<<< HEAD
    required this.post,
=======
    required DocumentSnapshot<Object?> post,
>>>>>>> 55e181723e12ebd57ed4017666666bc507c19b2d
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Color _background;
  late Color _accent;
  late Color _textLight;
  late Color _textDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Update colors based on theme
    _background = isDark ? const Color(0xFF2D3B3A) : const Color(0xFFF1E9D2);
    _accent = const Color(0xFFB88C66);
    _textLight = isDark ? Colors.white : const Color(0xFF293133);
    _textDark = isDark ? const Color(0xFF293133) : Colors.white;
  }

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
    _fetchPostDetails();
    _updateTimeAgo();
    _checkPostOwnership();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTimeAgo();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _timer?.cancel();
    _postSubscription.cancel();
    super.dispose();
  }

  void _updateTimeAgo() {
    setState(() {
      _timeAgo = _formatTimeAgo(widget.createdAt);
    });
  }

  void _checkPostOwnership() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      setState(() {
        isPostOwner = widget.post.get('userId') == currentUserId;
      });
    }
  }

  Future<void> _fetchPostDetails() async {
    _postSubscription = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
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
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    try {
      setState(() => _isLiking = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      
      if (isLiked) {
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
        });
      } else {
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([uid]),
        });
      }
    } catch (e) {
      _showErrorSnackBar('Could not update like status');
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _addComment() async {
    if (_isCommenting) return;
    
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    try {
      setState(() => _isCommenting = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Please sign in to comment');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userName = userDoc.data()?['fullName'] ?? user.displayName ?? 'Anonymous';

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
        'comments': FieldValue.arrayUnion([comment]),
        'commentDetails': FieldValue.arrayUnion([
          {
            'userId': user.uid,
            'userName': userName,
            'text': comment,
            'timestamp': Timestamp.now(),
          }
        ]),
      });

      _commentController.clear();
      
      // Send notification to post owner if they're not the commenter
      if (user.uid != widget.post.get('userId')) {      NotificationService.instance.createNotification(
        type: 'comment',
        toUserId: widget.post.get('userId'),
        postId: widget.postId,
        description: '$userName commented on your post',
      );
      }
    } catch (e) {
      _showErrorSnackBar('Could not add comment');
    } finally {      if (mounted) {
        setState(() => _isCommenting = false);
        _showMessage('Comment added successfully');
      }
    }
  }

  Future<void> _deletePost() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();
      
      Navigator.pop(context);
      _showMessage('Post deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Could not delete post');
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        animation: CurvedAnimation(
          parent: const AlwaysStoppedAnimation(1),
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  // Helper method to build glass container effect
  Widget _buildGlassContainer({
    required Widget child,
    required double height,
    double borderRadius = 16,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withOpacity(0.2)
              : _accent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark 
                  ? Colors.white.withOpacity(0.15)
                  : _accent.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  void _showMapBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDark = themeProvider.isDarkMode;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? _background : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Post Location',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? _textLight : _textDark,
                      ),
                    ),
                  ],
                ),
              ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildGlassContainer(
                  height: 60,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final url = 'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
                        if (await canLaunch(url)) {
                          await launch(url);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map,
                              color: isDark ? _accent : _accent.withOpacity(0.8),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Open in Google Maps',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: isDark ? _textLight : _textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.open_in_new,
                              color: (isDark ? _textLight : _textDark).withOpacity(0.5),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

<<<<<<< HEAD
=======
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

  Widget _buildLikesSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder:
          (context, controller) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: likes),
                        duration: const Duration(milliseconds: 500),
                        builder:
                            (context, value, child) => Text(
                              'Likes ($value)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.postId)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      final List<String> likedBy = List<String>.from(
                        data['likedBy'] ?? [],
                      );

                      if (likedBy.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No likes yet\nBe the first to like!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: Future.wait(
                          likedBy.map(
                            (uid) =>
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .get(),
                          ),
                        ),
                        builder: (context, userSnapshots) {
                          if (!userSnapshots.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final users = userSnapshots.data!;
                          return ListView.builder(
                            controller: controller,
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final userData =
                                  users[index].data() as Map<String, dynamic>?;
                              final userName =
                                  userData?['fullName'] ?? 'Anonymous';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    userName[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(userName),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

>>>>>>> 55e181723e12ebd57ed4017666666bc507c19b2d
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        elevation: 0,
        backgroundColor: isDark ? _background : _accent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? _textLight : Colors.white
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fullName,
              style: GoogleFonts.poppins(
                color: isDark ? _textLight : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _timeAgo,
              style: GoogleFonts.poppins(
                color: (isDark ? _textLight : Colors.white).withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (isPostOwner)
            IconButton(
              icon: Icon(Icons.delete, color: isDark ? _textLight : _textDark),
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
              child: _buildGlassContainer(
                height: widget.description.length > 100 ? 200 : 150,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
<<<<<<< HEAD
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? _accent.withOpacity(0.2) : _accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.category,
                          style: GoogleFonts.poppins(
                            color: isDark ? _accent : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
=======
                      AnimatedLikeButton(
                        isLiked: isLiked,
                        isLoading: _isLiking,
                        likes: likes,
                        onTap: _toggleLike,
                        showLikesList: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => _buildLikesSheet(),
                          );
                        },
>>>>>>> 55e181723e12ebd57ed4017666666bc507c19b2d
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.description,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          height: 1.5,
                          color: isDark ? _textLight : _textDark,
                        ),
                        maxLines: widget.description.length > 100 ? null : 3,
                        overflow: widget.description.length > 100 ? null : TextOverflow.ellipsis,
                      ),
                      const Spacer(),
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
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.latitude != 0 && widget.longitude != 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildGlassContainer(
                  height: 80,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showMapBottomSheet,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: _accent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'View Location',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? _textLight : _textDark,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: (isDark ? _textLight : _textDark).withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline,
                  color: Colors.red[400],
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Post?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? _textLight : _textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: (isDark ? _textLight : _textDark).withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: (isDark ? _textLight : _textDark).withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePost();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsSheet() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? _background : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
          bottom: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withOpacity(0.2)
              : _accent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? _textLight : _textDark).withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Comments (${commentDetails.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? _textLight : _textDark,
                  ),
                ),
                const Spacer(),
                if (commentDetails.isNotEmpty)
                  TextButton.icon(
                    icon: Icon(
                      Icons.sort,
                      color: _accent,
                      size: 20,
                    ),
                    label: Text(
                      'Latest',
                      style: GoogleFonts.poppins(
                        color: _accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      // Implement sorting if needed
                    },
                  ),
              ],
            ),
          ),
          Flexible(
            child: commentDetails.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: (isDark ? _textLight : _textDark).withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No comments yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: (isDark ? _textLight : _textDark).withOpacity(0.7),
                            ),
                          ),
                          Text(
                            'Be the first to comment',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: (isDark ? _textLight : _textDark).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: commentDetails.length,
                    itemBuilder: (context, index) {
                      final comment = commentDetails[index];
                      final timeAgo = _formatTimeAgo(
                        (comment['timestamp'] as Timestamp).toDate(),
                      );

                      return Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDark 
                                ? _background.withOpacity(0.7)
                                : _accent.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: isDark 
                                  ? _textLight.withOpacity(0.7)
                                  : _accent,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  comment['userName'] ?? 'Anonymous',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? _textLight : _textDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeAgo,
                                  style: GoogleFonts.poppins(
                                    color: (isDark ? _textLight : _textDark).withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                comment['text'],
                                style: GoogleFonts.poppins(
                                  color: isDark 
                                    ? _textLight.withOpacity(0.9)
                                    : _textDark.withOpacity(0.9),
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                          if (index < commentDetails.length - 1)
                            Divider(
                              indent: 72,
                              color: (isDark ? _textLight : _textDark).withOpacity(0.1),
                            ),
                        ],
                      );
                    },
                  ),
          ),
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
                    style: GoogleFonts.poppins(
                      color: isDark ? _textLight : _textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: GoogleFonts.poppins(
                        color: (isDark ? _textLight : _textDark).withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark 
                            ? Colors.white.withOpacity(0.1)
                            : _accent.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark 
                            ? Colors.white.withOpacity(0.1)
                            : _accent.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: _accent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      fillColor: isDark 
                        ? Colors.white.withOpacity(0.1)
                        : _accent.withOpacity(0.05),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _accent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: _isCommenting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }
}
