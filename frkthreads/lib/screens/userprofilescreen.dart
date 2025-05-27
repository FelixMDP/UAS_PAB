import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frkthreads/screens/postdetailscreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/services/notification_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _currentUid = FirebaseAuth.instance.currentUser?.uid;
  late Color _background;
  late Color _accent;
  late Color _card;
  late Color _textLight;
  late Color _textDark;
  int _selectedTab = 0;

  late Stream<bool> _isFollowingStream;
  late Stream<int> _followerCountStream;
  late Stream<int> _followingCountStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
    _initializeColors();
  }

  void _initializeColors() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _updateColors(themeProvider.isDarkMode);
  }

  void _updateColors(bool isDark) {
    // Using theme provider's color constants
    _background = isDark ? const Color(0xFF1A2327) : const Color(0xFFF5F0E5);
    _accent = isDark ? const Color(0xFF64B5F6) : const Color(0xFFB88C66);
    _card = isDark ? const Color(0xFF37474F) : Colors.white;
    _textLight = isDark ? const Color(0xFFF1E9D2) : const Color(0xFF293133);
    _textDark = isDark ? Colors.black87 : Colors.white;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    _updateColors(themeProvider.isDarkMode);
  }

  void _initializeStreams() {
    if (_currentUid != null) {
      // Stream to check if current user is following this profile
      _isFollowingStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .snapshots()
          .map((doc) {
            final following =
                (doc.data()?['following'] as List?)?.cast<String>() ?? [];
            return following.contains(widget.userId);
          });

      // Stream for followers count
      _followerCountStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots()
          .map((doc) => (doc.data()?['followers'] as List?)?.length ?? 0);

      // Stream for following count
      _followingCountStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots()
          .map((doc) => (doc.data()?['following'] as List?)?.length ?? 0);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} detik yang lalu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
  Widget _buildGlassContainer({
    required Widget child,
    double height = 200,
    double borderRadius = 20,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.2) : _accent.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : _accent.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStats() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .snapshots()
          .map((snap) => snap.docs.first),
      builder: (context, snapshot) {
        return FadeInUp(
          delay: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildGlassContainer(
              height: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('posts')
                            .where('userId', isEqualTo: widget.userId)
                            .snapshots(),
                    builder: (context, snapshot) {
                      int postsCount =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildStatItem(
                        title: 'Posts',
                        value: postsCount.toString(),
                        icon: Icons.post_add,
                      );
                    },
                  ),
                  _buildDivider(),
                  StreamBuilder<int>(
                    stream: _followerCountStream,
                    builder: (context, snapshot) {
                      return _buildStatItem(
                        title: 'Followers',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.people,
                      );
                    },
                  ),
                  _buildDivider(),
                  StreamBuilder<int>(
                    stream: _followingCountStream,
                    builder: (context, snapshot) {
                      return _buildStatItem(
                        title: 'Following',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.person_add,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow() async {
    if (_currentUid == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid);
    final targetUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);

    final userDoc = await userRef.get();
    final following = List<String>.from(userDoc.data()?['following'] ?? []);
    final isFollowing = following.contains(widget.userId);

    if (isFollowing) {
      // Unfollow
      await userRef.update({
        'following': FieldValue.arrayRemove([widget.userId]),
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayRemove([_currentUid]),
      });
    } else {
      // Follow
      await userRef.update({
        'following': FieldValue.arrayUnion([widget.userId]),
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayUnion([_currentUid]),
      });

      // Create follow notification
      await NotificationService.instance.createNotification(
        type: 'follow',
        toUserId: widget.userId,
        postId: '', // Empty postId for follow notifications
        description: 'started following you',
      );
    }
  }

  Widget _buildFollowButton() {
    if (_currentUid == widget.userId) {
      return const SizedBox.shrink(); // Don't show button on own profile
    }

    return StreamBuilder<bool>(
      stream: _isFollowingStream,
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? _accent.withOpacity(0.2) : _accent,
            foregroundColor: isFollowing ? _accent : _textLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _toggleFollow,
          child: Text(
            isFollowing ? 'Unfollow' : 'Follow',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _textLight.withOpacity(0.9), size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: _textLight,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: _textLight.withOpacity(0.8),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: _textLight.withOpacity(0.2));
  }

 Widget _buildTabButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _buildGlassContainer(
        height: 70,
        borderRadius: 25,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _buildTabButton(
                title: 'Posts',
                icon: Icons.grid_on_rounded,
                index: 0,
              ),
              _buildTabButton(
                title: 'Liked',
                icon: Icons.favorite_rounded,
                index: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
          HapticFeedback.lightImpact();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isSelected ? _accent.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          margin: const EdgeInsets.all(5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? _accent : _textLight.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: isSelected ? _accent : _textLight.withOpacity(0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _selectedTab == 0 ? _buildPosts() : _buildLikedPosts(),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: _background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final fullName = userData['fullName'] ?? 'Username';
        final bio = userData['bio'] ?? '';

        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            backgroundColor: _background,
            elevation: 0,
            title: Text(
              fullName,
              style: GoogleFonts.poppins(
                color: _textLight,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: _textLight),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(userData, fullName, bio),
                const SizedBox(height: 16),
                _buildStats(),
                const SizedBox(height: 16),
                _buildTabButtons(),
                _buildTabContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic> data, String fullName, String bio) {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildGlassContainer(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'profile-${widget.userId}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child:
                        data['profileImage'] != null
                            ? ClipOval(
                              child: Image.memory(
                                base64Decode(data['profileImage']!),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            )
                            : CircleAvatar(
                              radius: 40,
                              backgroundColor: _card,
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: _textDark,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.poppins(
                          color: _textLight,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          style: GoogleFonts.poppins(
                            color: _textLight.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_currentUid != widget.userId)
                        StreamBuilder<bool>(
                          stream: _isFollowingStream,
                          builder: (context, snapshot) {
                            final isFollowing = snapshot.data ?? false;

                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isFollowing
                                        ? _accent.withOpacity(0.2)
                                        : _accent,
                                foregroundColor:
                                    isFollowing ? _accent : _textLight,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(double.infinity, 36),
                              ),
                              onPressed: _toggleFollow,
                              child: Text(
                                isFollowing ? 'Unfollow' : 'Follow',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
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
  }

   Widget _buildPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: widget.userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildPostsSkeleton();
        }

        final posts = snapshot.data!.docs;
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.post_add_rounded,
                  size: 64,
                  color: _textLight.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: GoogleFonts.poppins(
                    color: _textLight.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              padding: const EdgeInsets.only(top: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
  final postDocument = posts[index];
  final post = postDocument.data() as Map<String, dynamic>;
  final String? imageBase64 = post['image'] as String?; // Ambil string base64

  // Logika untuk createdAt (sudah Anda perbaiki, pastikan DateTime.tryParse lebih aman untuk String)
  DateTime createdAt;
  final dynamic createdAtData = post['createdAt'];
  if (createdAtData is Timestamp) {
    createdAt = createdAtData.toDate();
  } else if (createdAtData is String) {
    // Gunakan tryParse untuk keamanan jika string tidak valid
    createdAt = DateTime.tryParse(createdAtData) ?? DateTime.now();
    if (DateTime.tryParse(createdAtData) == null) {
      print("WARN UserProfileScreen _buildPosts: Gagal parse String createdAt '${createdAtData}' untuk post ${postDocument.id}");
    }
  } else {
    createdAt = DateTime.now(); 
    if (createdAtData != null) { // Hanya print jika bukan null tapi tipe salah
        print("WARN UserProfileScreen _buildPosts: createdAt tipe tidak dikenal (${createdAtData.runtimeType}) untuk post ${postDocument.id}, menggunakan DateTime.now()");
    } else {
        print("WARN UserProfileScreen _buildPosts: createdAt null untuk post ${postDocument.id}, menggunakan DateTime.now()");
    }
  }

  return FadeInUp(
    delay: Duration(milliseconds: index * 50),
    duration: const Duration(milliseconds: 500),
    child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(
              post: postDocument,
              postId: postDocument.id,
              imageBase64: imageBase64 ?? '',
              description: post['description'] as String? ?? '',
              createdAt: createdAt, // Sesuaikan dengan nama parameter di DetailScreen
              fullName: post['fullName'] as String? ?? 'Anonymous',
              latitude: post['latitude'] as double? ?? 0.0,
              longitude: post['longitude'] as double? ?? 0.0,
              category: post['category'] as String? ?? 'Uncategorized',
              heroTag: 'post_${postDocument.id}',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _card, // Menggunakan variabel state _card
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: (imageBase64 != null && imageBase64.isNotEmpty)
              ? Builder(builder: (context) { // Builder untuk try-catch decode
                  Uint8List? decodedBytes;
                  String base64ToDecode = imageBase64;

                  // Membersihkan prefix data URI jika ada
                  if (base64ToDecode.startsWith('data:image')) {
                    try {
                      base64ToDecode = base64ToDecode.substring(base64ToDecode.indexOf(',') + 1);
                    } catch (e) {
                      print("Error memotong prefix base64: $e");
                      // Biarkan base64ToDecode apa adanya jika pemotongan gagal, mungkin akan error di base64Decode
                    }
                  }
                  
                  try {
                    decodedBytes = base64Decode(base64ToDecode);
                  } catch (e) {
                    print("!!! ERROR base64Decode di UserProfileScreen post ${postDocument.id}: $e");
                    // decodedBytes akan tetap null, sehingga placeholder ditampilkan
                  }

                  if (decodedBytes != null) {
                    return Image.memory(
                      decodedBytes,
                      fit: BoxFit.cover,
                      width: double.infinity, // Pastikan gambar mengisi kontainer
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        print("!!! ERROR Image.memory di UserProfileScreen post ${postDocument.id}: $error");
                        return Container(
                          color: _card,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image, // Ikon berbeda untuk error render
                            color: _textDark.withOpacity(0.5),
                            size: 32,
                          ),
                        );
                      },
                    );
                  } else {
                    // Jika decode gagal, tampilkan placeholder
                    return Container(
                      color: _card,
                      alignment: Alignment.center,
                      child: Icon(Icons.image_not_supported, color: _textDark.withOpacity(0.3), size: 32),
                    );
                  }
                })
              : Container( // Placeholder jika imageBase64 null atau kosong
                  color: _card,
                  alignment: Alignment.center,
                  child: Icon(Icons.image_not_supported, color: _textDark.withOpacity(0.3), size: 32),
                ),
        ),
      ),
    ),
  );
},
            ),
          ),
        );
      },
    );
  }

 Widget _buildLikedPosts() {
    if (widget.userId == null) return _buildEmptyState("User not identified.");

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .where('likedBy', arrayContains: widget.userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No liked posts yet");
        }

        final posts = snapshot.data!.docs;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            padding: const EdgeInsets.only(top: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;
              final imageBase64 = post['image'] as String?;

              return FadeInUp(
                delay: Duration(milliseconds: index * 50),
                duration: const Duration(milliseconds: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // Convert timestamp if needed
                          DateTime createdAt;
                          if (post['createdAt'] is Timestamp) {
                            createdAt = (post['createdAt'] as Timestamp).toDate();
                          } else if (post['createdAt'] is String) {
                            createdAt = DateTime.parse(post['createdAt']);
                          } else {
                            createdAt = DateTime.now();
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailScreen(
                                post: posts[index],
                                postId: posts[index].id, 
                                imageBase64: imageBase64 ?? '',
                                description: post['description'] ?? '',
                                createdAt: createdAt,
                                fullName: post['fullName'] ?? 'Anonymous',
                                latitude: post['latitude'] ?? 0.0,
                                longitude: post['longitude'] ?? 0.0,
                                category: post['category'] ?? 'Uncategorized',
                                heroTag: 'liked_post_${posts[index].id}',
                              ),
                            ),
                          );
                        },
                        child:
                            imageBase64 != null && imageBase64.isNotEmpty
                                ? Image.memory(
                                  base64Decode(imageBase64),
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        color: _card,
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: _textDark.withOpacity(0.3),
                                        ),
                                      ),
                                )
                                : Container(
                                  color: _card,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: _textDark.withOpacity(0.3),
                                  ),
                                ),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTab == 0 ? Icons.post_add_rounded : Icons.favorite_border,
            size: 64,
            color: _textLight.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: _textLight.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedTab == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Share your moments with others',
                style: GoogleFonts.poppins(
                  color: _textLight.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostsSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final DateTime timestamp;
  final int index;
  final Function(DateTime) getTimeAgo;

  const PostCard({
    super.key,
    required this.post,
    required this.timestamp,
    required this.index,
    required this.getTimeAgo,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  late Color _card;
  late Color _textColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _initializeColors();
  }

  void _initializeColors() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _updateColors(themeProvider.isDarkMode);
  }

  void _updateColors(bool isDark) {
    _card = isDark ? const Color(0xFF37474F) : Colors.white;
    _textColor = isDark ? const Color(0xFFF1E9D2) : const Color(0xFF293133);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    _updateColors(themeProvider.isDarkMode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
          _controller.forward();
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
          _controller.reverse();
        });
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: _textColor.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.post['image'] != null && widget.post['image'].isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Image.memory(
                    base64Decode(widget.post['image']),
                    fit: BoxFit.cover,
                    height: 150,
                    width: double.infinity,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.post['description'] != null)
                      Text(
                        widget.post['description'],
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, 
                          size: 14, 
                          color: _textColor.withOpacity(0.7)
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.getTimeAgo(widget.timestamp),
                          style: TextStyle(
                            color: _textColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
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
    );
  }
}
