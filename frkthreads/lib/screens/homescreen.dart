import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frkthreads/screens/postdetailscreen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'addpostscreen.dart';
import 'searchscreen.dart';
import 'notificationscreen.dart';
import 'profilescreen.dart';
import 'signinscreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _controller;

  // Helper to map _selectedIndex (0-3) to CurvedNavigationBar index (0-4)
  int _mapSelectedIndexToNavBarIndex(int selectedIndex) {
    if (selectedIndex >= 2) {
      return selectedIndex + 1; // skip placeholder at index 2
    }
    return selectedIndex;
  }

  // Helper to map CurvedNavigationBar index (0-4) to _selectedIndex (0-3)
  int _mapNavBarIndexToSelectedIndex(int navBarIndex) {
    if (navBarIndex > 2) {
      return navBarIndex - 1; // skip placeholder at index 2
    } else if (navBarIndex == 2) {
      // Placeholder tapped, ignore or keep current index
      return _selectedIndex;
    }
    return navBarIndex;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final List<Widget> _widgetOptions = <Widget>[
    const PostListView(),
    const SearchScreen(),
    NotificationScreen(),
    const ProfileScreen(),
  ];
  void _onItemTapped(int index) {
    // Map tapped index to _selectedIndex ignoring placeholder
    final mappedIndex = _mapNavBarIndexToSelectedIndex(index);
    setState(() {
      _selectedIndex = mappedIndex;
    });
  }

  Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const SignInScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFB88C66),
        title: ShaderMask(
          shaderCallback:
              (bounds) => LinearGradient(
                colors:
                    isDark
                        ? [Colors.white, Colors.white70]
                        : [Colors.white, Colors.white.withOpacity(0.8)],
              ).createShader(bounds),
          child: const Text(
            'FRKTHREADS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
            radius: 16,
          ),
          const SizedBox(width: 10),
        ],
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _widgetOptions[_selectedIndex],
      ),
      floatingActionButton: ScaleTransition(
        scale: _controller,
        child: FloatingActionButton(
          backgroundColor: isDark ? Colors.blue[700] : const Color(0xFF2D3B3A),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const AddPostScreen(),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
              ),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor:
            isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
        color: isDark ? Colors.grey[900]! : const Color(0xFFB88C66),
        buttonBackgroundColor:
            isDark ? Colors.blue[700] : const Color(0xFF2D3B3A),
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        animationCurve: Curves.easeInOut,
        index: _mapSelectedIndexToNavBarIndex(_selectedIndex),
        onTap: _onItemTapped,
        letIndexChange: (index) => index != 2,
        items: <Widget>[
          Icon(
            Icons.home_rounded,
            size: 30,
            color:
                _selectedIndex == 0
                    ? Colors.white
                    : isDark
                    ? Colors.white70
                    : Colors.white,
          ),
          Icon(
            Icons.search_rounded,
            size: 30,
            color:
                _selectedIndex == 1
                    ? Colors.white
                    : isDark
                    ? Colors.white70
                    : Colors.white,
          ),
          const SizedBox(width: 30), // Placeholder for FAB
          Icon(
            Icons.notifications_rounded,
            size: 30,
            color:
                _selectedIndex == 2
                    ? Colors.white
                    : isDark
                    ? Colors.white70
                    : Colors.white,
          ),
          Icon(
            Icons.person_rounded,
            size: 30,
            color:
                _selectedIndex == 3
                    ? Colors.white
                    : isDark
                    ? Colors.white70
                    : Colors.white,
          ),
        ],
      ),
    );
  }
}

class PostListView extends StatelessWidget {
  const PostListView({super.key});

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} detik yang lalu';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit yang lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam yang lalu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} hari yang lalu';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  Future<void> _handleShare(Map<String, dynamic> data) async {
    try {
      final description = data['description'] ?? '';
      final fullName = data['fullName'] ?? 'Anonymous';
      final shareText = 'Post by $fullName\n\n$description';
      await Share.share(shareText);
    } catch (e) {
      debugPrint('Error sharing post: $e');
    }
  }

  Future<void> _deletePost(
    BuildContext context,
    String postId,
    String userId,
  ) async {
    // Check if current user is the post owner
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own posts')),
      );
      return;
    }

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text('Are you sure you want to delete this post?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete != true) return;

    try {
      // Delete the post
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return StreamBuilder(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(
                isDark ? Colors.white : Colors.black87,
              ),
            ),
          );
        }

        final posts = snapshot.data!.docs;

        return AnimationLimiter(
          child: ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final data = posts[index].data();
              final imageBase64 = data['image'];
              final description = data['description'];
              final createdAtStr = data['createdAt'];
              final fullName = data['fullName'] ?? 'Anonim';

              DateTime createdAt;
              if (createdAtStr is String) {
                createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
              } else if (createdAtStr is Timestamp) {
                createdAt = createdAtStr.toDate();
              } else {
                createdAt = DateTime.now();
              }

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Card(
                      margin: const EdgeInsets.all(10),
                      color: isDark ? Colors.grey[850] : Colors.white,
                      elevation: 4,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageBase64 != null)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => DetailScreen(
                                          postId: posts[index].id,
                                          imageBase64: imageBase64,
                                          description:
                                              data['description'] ?? '',
                                          createdAt: createdAt,
                                          fullName:
                                              data['fullName'] ?? 'Anonymous',
                                          latitude: data['latitude'] ?? 0.0,
                                          longitude: data['longitude'] ?? 0.0,
                                          category:
                                              data['category'] ??
                                              'Uncategorized',
                                          heroTag: 'post_${posts[index].id}',
                                        ),
                                  ),
                                );
                              },
                              child: Hero(
                                tag: 'post_${posts[index].id}',
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(15),
                                  ),
                                  child: Image.memory(
                                    base64Decode(imageBase64),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              isDark
                                                  ? Colors.grey[700]
                                                  : Colors.grey[200],
                                          radius: 20,
                                          child: Text(
                                            fullName[0].toUpperCase(),
                                            style: TextStyle(
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fullName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              formatTime(createdAt),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    isDark
                                                        ? Colors.grey[400]
                                                        : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    PopupMenuButton(
                                      itemBuilder:
                                          (context) => [
                                            if (data['userId'] ==
                                                FirebaseAuth
                                                    .instance
                                                    .currentUser
                                                    ?.uid)
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: const [
                                                    Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _deletePost(
                                            context,
                                            posts[index].id,
                                            data['userId'],
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        isDark
                                            ? Colors.grey[300]
                                            : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        (data['likedBy'] ?? []).contains(
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid,
                                            )
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color:
                                            (data['likedBy'] ?? []).contains(
                                                  FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.uid,
                                                )
                                                ? Colors.red
                                                : isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                      ),
                                      onPressed:
                                          () => _toggleLike(posts[index].id),
                                    ),
                                    Text('${data['likes'] ?? 0}'),
                                    IconButton(
                                      icon: Icon(
                                        Icons.comment_outlined,
                                        color:
                                            isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => DetailScreen(
                                                  postId: posts[index].id,
                                                  imageBase64: data['image'],
                                                  description:
                                                      data['description'] ?? '',
                                                  createdAt: DateTime.parse(
                                                    data['createdAt'],
                                                  ),
                                                  fullName:
                                                      data['fullName'] ??
                                                      'Anonymous',
                                                  latitude:
                                                      data['latitude'] ?? 0.0,
                                                  longitude:
                                                      data['longitude'] ?? 0.0,
                                                  category:
                                                      data['category'] ??
                                                      'Uncategorized',
                                                  heroTag:
                                                      'post_${posts[index].id}',
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                    Text('${(data['comments'] ?? []).length}'),
                                    IconButton(
                                      icon: Icon(
                                        Icons.share_outlined,
                                        color:
                                            isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                      ),
                                      onPressed: () => _handleShare(data),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),  
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget buildPostCard(DocumentSnapshot post, BuildContext context) {
    final data = post.data() as Map<String, dynamic>;
    final imageBase64 = data['image'] as String?;
    final createdAt = DateTime.parse(data['createdAt'] as String);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => DetailScreen(
                  postId: post.id,
                  imageBase64: imageBase64!,
                  description: data['description'],
                  createdAt: createdAt,
                  fullName: data['fullName'],
                  latitude: data['latitude'],
                  longitude: data['longitude'],
                  category: data['category'],
                  heroTag: 'post_${post.id}',
                ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.all(10),
        color: Colors.white, // Using the consistent card color.
        elevation: 2, // Added a small elevation for better appearance
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageBase64 != null)
              Hero(
                tag: 'post_${post.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  child: Image.memory(
                    base64Decode(imageBase64),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    data['fullName'] ?? 'Anonim',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data['description'] ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      (data['likedBy'] ?? []).contains(
                            FirebaseAuth.instance.currentUser?.uid,
                          )
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          (data['likedBy'] ?? []).contains(
                                FirebaseAuth.instance.currentUser?.uid,
                              )
                              ? Colors.red
                              : null,
                    ),
                    onPressed: () => _toggleLike(post.id),
                  ),
                  Text('${data['likes'] ?? 0}'),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () {
                      Navigator.pushNamed(context, '/post', arguments: post.id);
                    },
                  ),
                  Text('${(data['comments'] ?? []).length}'),
                  if (data['latitude'] != null && data['longitude'] != null)
                    IconButton(
                      icon: const Icon(Icons.location_on),
                      onPressed: () {
                        _showLocationMap(context, data);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final doc = await postRef.get();

    if (!doc.exists) return;

    final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);

    if (likedBy.contains(uid)) {
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
  }

  void _showLocationMap(BuildContext context, Map<String, dynamic> data) {
    final latitude = data['latitude'] as double?;
    final longitude = data['longitude'] as double?;

    if (latitude == null || longitude == null) return;

    showModalBottomSheet(
      context: context,
      builder:
          (context) => SizedBox(
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

  Future<void> _createNotification({
    required String type,
    required String toUserId,
    required String postId,
    required String description,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': type,
        'fromUserId': currentUser.uid,
        'fromUserName': currentUser.displayName ?? 'Anonymous',
        'toUserId': toUserId,
        'postId': postId,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }
}
