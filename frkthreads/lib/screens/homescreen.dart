import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frkthreads/screens/postdetailscreen.dart';
import 'package:frkthreads/screens/search_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:frkthreads/widgets/story_list.dart';
import 'package:frkthreads/services/notification_service.dart';
import 'addpostscreen.dart';
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
  late final AnimationController _controller;
  final String? _currentUserUID = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _controller.forward();

    // Add post frame callback to check auth state and redirect if anonymous
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        Navigator.pushReplacementNamed(context, '/signin');
      }
    });
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
  int _mapSelectedIndexToNavBarIndex(int selectedIndex) {
    if (selectedIndex >= 2) {
      return selectedIndex + 1; // skip placeholder at index 2
    }
    return selectedIndex;
  }

  int _mapNavBarIndexToSelectedIndex(int navBarIndex) {
    if (navBarIndex > 2) {
      return navBarIndex - 1; // skip placeholder at index 2
    } else if (navBarIndex == 2) {
      // Placeholder tapped, ignore or keep current index
      return _selectedIndex;
    }
    return navBarIndex;
  }

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
          // const SizedBox(width: 10), // Dihapus karena Padding akan menangani jarak

          // --- Implementasi StreamBuilder untuk CircleAvatar Foto Profil ---
          if (_currentUserUID != null)
            StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUserUID)
                      .snapshots(),
              builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                String? profileImageBase64;
                String initialLetter = '?'; // Default jika tidak ada nama

                if (snapshot.connectionState == ConnectionState.active) {
                  // Cek jika stream aktif
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    if (userData != null) {
                      profileImageBase64 = userData['profileImage'] as String?;
                      final fullName =
                          (userData['fullName'] as String?)?.isNotEmpty == true
                              ? userData['fullName'] as String
                              : (FirebaseAuth
                                      .instance
                                      .currentUser
                                      ?.displayName ??
                                  '');
                      if (fullName.isNotEmpty) {
                        initialLetter = fullName[0].toUpperCase();
                      }
                    }
                  } else if (FirebaseAuth
                          .instance
                          .currentUser
                          ?.displayName
                          ?.isNotEmpty ==
                      true) {
                    // Fallback ke displayName dari Auth jika Firestore doc belum ada atau fullName kosong
                    initialLetter =
                        FirebaseAuth.instance.currentUser!.displayName![0]
                            .toUpperCase();
                  }
                }
                // Saat loading atau error, bisa tampilkan placeholder sederhana
                // atau biarkan CircleAvatar menampilkan initialLetter default / background color.

                return GestureDetector(
                  onTap: () {
                    // Navigasi ke ProfileScreen saat CircleAvatar di-tap
                    // Jika Anda ingin mengganti tab di BottomNavBar ke ProfileScreen (indeks 3):
                    if (_selectedIndex != 3) {
                      // Cek agar tidak setState jika sudah di tab profil
                      _onItemTapped(
                        _mapSelectedIndexToNavBarIndex(3),
                      ); // map 3 ke nav bar index
                    }
                    // Atau jika ingin push halaman ProfileScreen secara independen:
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    // );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0, left: 4.0),
                    child: CircleAvatar(
                      key: ValueKey(
                        profileImageBase64,
                      ), // Force refresh when image changes
                      radius: 18,
                      backgroundColor:
                          isDark
                              ? Colors.grey[700]
                              : Colors.white.withOpacity(0.7),
                      child:
                          (profileImageBase64 != null &&
                                  profileImageBase64.isNotEmpty)
                              ? Builder(
                                builder: (context) {
                                  try {
                                    String effectiveBase64 =
                                        profileImageBase64!;
                                    if (profileImageBase64!.contains(',')) {
                                      effectiveBase64 =
                                          profileImageBase64!.split(',')[1];
                                    }
                                    final imageBytes = base64Decode(
                                      effectiveBase64,
                                    );
                                    return ClipOval(
                                      child: Image.memory(
                                        imageBytes,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          debugPrint(
                                            'Error loading profile image: $error',
                                          );
                                          return Text(
                                            initialLetter,
                                            style: TextStyle(
                                              color:
                                                  isDark
                                                      ? Colors.white70
                                                      : Colors.black54,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint(
                                      'Error decoding profile image: $e',
                                    );
                                    return Text(
                                      initialLetter,
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }
                                },
                              )
                              : Text(
                                initialLetter,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                );
              },
            )
          else // Jika tidak ada user login (currentUserUID null), tampilkan placeholder
            Padding(
              padding: const EdgeInsets.only(right: 12.0, left: 4.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor:
                    isDark ? Colors.grey[700] : Colors.white.withOpacity(0.7),
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          // const SizedBox(width: 10), // Dihapus
        ],
        elevation: 2, // Anda bisa sesuaikan elevasinya
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child:
            _selectedIndex == 0
                ? Column(
                  children: [
                    const StoryList(),
                    Expanded(child: _widgetOptions[_selectedIndex]),
                  ],
                )
                : _widgetOptions[_selectedIndex],
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
      return '1 menit yang lalu';
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

      final imageBase64 = data['image'] as String?;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        // Decode base64 image
        final bytes = base64Decode(imageBase64);

        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/shared_image.png');

        // Write bytes to file
        await file.writeAsBytes(bytes);

        // Share image file with text
        await Share.shareXFiles([XFile(file.path)], text: shareText);
      } else {
        // Share text only
        await Share.share(shareText);
      }
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
              final data = posts[index].data() as Map<String, dynamic>;
              final imageBase64 = data['image'] as String?;
              final description = data['description'] as String? ?? '';
              final createdAtStr = data['createdAt'];
              final fullName = data['fullName'] as String? ?? 'Anonim';

              DateTime createdAt;
              if (createdAtStr is String) {
                createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
              } else if (createdAtStr is Timestamp) {
                createdAt = createdAtStr.toDate();
              } else {
                createdAt = DateTime.now();
              }

              final List<dynamic> commentDetailsList =
                  data['commentDetails'] as List<dynamic>? ?? [];
              final int currentCommentCount = commentDetailsList.length;

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors:
                              isDark
                                  ? [Colors.grey[850]!, Colors.grey[900]!]
                                  : [
                                    const Color(0xFFFFF3E0),
                                    const Color(0xFFFFE0B2),
                                  ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: Stack(
                              children: [
                                if (imageBase64 != null)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => DetailScreen(
                                                post: posts[index],
                                                postId: posts[index].id,
                                                imageBase64: imageBase64,
                                                description: description,
                                                createdAt: createdAt,
                                                fullName: fullName,
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
                                    child: Hero(
                                      tag: 'post_${posts[index].id}',
                                      child: Image.memory(
                                        base64Decode(imageBase64),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 250,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    isDark
                                                        ? Colors.black
                                                            .withOpacity(0.3)
                                                        : Colors.grey
                                                            .withOpacity(0.3),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: StreamBuilder<
                                            DocumentSnapshot
                                          >(
                                            stream:
                                                FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(data['userId'])
                                                    .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final userData =
                                                    snapshot.data!.data()
                                                        as Map<
                                                          String,
                                                          dynamic
                                                        >?;
                                                final profileImage =
                                                    userData?['profileImage']
                                                        as String?;

                                                if (profileImage != null &&
                                                    profileImage.isNotEmpty) {
                                                  try {
                                                    String effectiveBase64 =
                                                        profileImage;
                                                    if (profileImage.contains(
                                                      ',',
                                                    )) {
                                                      effectiveBase64 =
                                                          profileImage.split(
                                                            ',',
                                                          )[1];
                                                    }
                                                    final imageBytes =
                                                        base64Decode(
                                                          effectiveBase64,
                                                        );

                                                    return CircleAvatar(
                                                      radius: 24,
                                                      backgroundColor:
                                                          isDark
                                                              ? Colors.grey[800]
                                                              : Colors.white,
                                                      child: ClipOval(
                                                        child: Image.memory(
                                                          imageBytes,
                                                          width: 48,
                                                          height: 48,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stack,
                                                              ) => Text(
                                                                fullName[0]
                                                                    .toUpperCase(),
                                                                style: TextStyle(
                                                                  color:
                                                                      isDark
                                                                          ? Colors
                                                                              .white
                                                                          : Colors
                                                                              .black87,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 18,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    debugPrint(
                                                      'Error decoding profile image: $e',
                                                    );
                                                  }
                                                }
                                              }

                                              return CircleAvatar(
                                                backgroundColor:
                                                    isDark
                                                        ? Colors.grey[800]
                                                        : Colors.white,
                                                radius: 24,
                                                child: Text(
                                                  fullName[0].toUpperCase(),
                                                  style: TextStyle(
                                                    color:
                                                        isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
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
                                const SizedBox(height: 12),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        isDark
                                            ? Colors.grey[300]
                                            : Colors.black87,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildInteractionButton(
                                      icon:
                                          (data['likedBy'] as List<dynamic>? ??
                                                      [])
                                                  .contains(
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid,
                                                  )
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                      color:
                                          (data['likedBy'] as List<dynamic>? ??
                                                      [])
                                                  .contains(
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid,
                                                  )
                                              ? Colors.red
                                              : (isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600]),
                                      count: data['likes'] ?? 0,
                                      onTap: () => _toggleLike(posts[index].id),
                                      isDark: isDark,
                                    ),
                                    _buildInteractionButton(
                                      icon: Icons.comment_outlined,
                                      color:
                                          isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                      count: currentCommentCount,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => DetailScreen(
                                                  post: posts[index],
                                                  postId: posts[index].id,
                                                  imageBase64:
                                                      imageBase64 ?? '',
                                                  description: description,
                                                  createdAt: createdAt,
                                                  fullName: fullName,
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
                                      isDark: isDark,
                                    ),
                                    _buildInteractionButton(
                                      icon: Icons.share_outlined,
                                      color:
                                          isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                      count: null,
                                      onTap: () => _handleShare(data),
                                      isDark: isDark,
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

  Widget _buildInteractionButton({
    required IconData icon,
    required Color? color,
    required Function() onTap,
    required bool isDark,
    int? count,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.grey[850]!.withOpacity(0.5)
                : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                if (count != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
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

      // Create notification when someone likes a post
      final postData = doc.data()!;
      final postOwnerId = postData['userId'];
      if (postOwnerId != uid) {
        await NotificationService.instance.createNotification(
          type: 'like',
          toUserId: postOwnerId,
          postId: postId,
          description: 'liked your post',
        );
      }
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
}
