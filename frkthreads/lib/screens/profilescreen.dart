import 'dart:convert';
import 'dart:ui';

import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/screens/editprofilescreen.dart';
import 'package:frkthreads/screens/followers_screen.dart';
import 'package:frkthreads/screens/following_screen.dart';
import 'package:frkthreads/screens/postdetailscreen.dart';
import 'package:frkthreads/screens/signinscreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  int _selectedTab = 0;

  // Define your theme colors here
  late Color _background;
  late Color _accent;
  late Color _textLight;
  late Color _textDark;
  late Color _card;
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    _background = isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2);
    _accent = isDark ? const Color(0xFF92D5E6) : const Color(0xFF5C8374);
    _textLight = isDark ? Colors.white : Colors.black;
    _textDark = isDark ? Colors.black : Colors.white;
    _card = isDark ? const Color(0xFF37474F) : Colors.white;
  }

  Widget _buildGlassContainer({
    required Widget child,
    double height = 200,
    double borderRadius = 20,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeaderSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 24, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 16, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? _accent.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected
                          ? _accent.withOpacity(0.3)
                          : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: _accent.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? _accent : _textLight.withOpacity(0.7),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: isSelected ? _accent : _textLight.withOpacity(0.7),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                bottom: 0,
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsSkeleton() {
    return Padding(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    _background = isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2);
    _accent = isDark ? const Color(0xFF92D5E6) : const Color(0xFF5C8374);
    _textLight = isDark ? Colors.white : Colors.black;
    _textDark = isDark ? Colors.black : Colors.white;
    _card = isDark ? const Color(0xFF37474F) : Colors.white;

    if (_uid == null) {
      return Scaffold(
        backgroundColor: _background,
        body: const Center(child: Text('User not logged in.')),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(_uid)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: _buildHeaderSkeleton(),
                    ),
                    const SizedBox(height: 16),
                    _buildTabButtons(),
                    _buildPostsSkeleton(),
                  ],
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data?.data() == null) {
              return Center(
                child: Text(
                  'User data not found. Try editing your profile.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final fullName =
                (data['fullName'] as String?)?.isNotEmpty == true
                    ? data['fullName'] as String
                    : (FirebaseAuth.instance.currentUser?.displayName ??
                        'Anonymous');
            final bio = data['bio'] as String? ?? 'No bio yet';

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom + 16,
              ),
              child: Column(
                children: [
                  _buildHeader(data, fullName, bio),
                  const SizedBox(height: 16),
                  _buildStats(),
                  const SizedBox(height: 16),
                  _buildTabButtons(),
                  _buildTabContent(),
                ],
              ),
            );
          },
        ),
      ),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Image Section
                Hero(
                  tag: 'profile-$_uid',
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
                        data['profileImage'] != null &&
                                (data['profileImage'] as String).isNotEmpty
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
                      const SizedBox(
                        height: 16,
                      ), // Buttons Section with fixed height
                      SizedBox(
                        height: 36, // Fixed height to prevent overflow
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent.withOpacity(0.2),
                                  foregroundColor: _accent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EditProfileScreen(),
                                    ),
                                  );
                                },
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Edit Profile',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: Material(
                                color: _accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _showSettingsDialog(),
                                  child: Center(
                                    child: Icon(
                                      Icons.settings,
                                      color: _accent,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildStats() {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
      builder: (context, userSnapshot) {
        int followersCount = 0;
        int followingCount = 0;

        if (userSnapshot.hasData && userSnapshot.data != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            followersCount = (userData['followers'] as List?)?.length ?? 0;
            followingCount = (userData['following'] as List?)?.length ?? 0;
          }
        }

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
                            .where('userId', isEqualTo: _uid)
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
                  _buildStatItem(
                    title: 'Followers',
                    value: followersCount.toString(),
                    icon: Icons.people,
                    onTap: () {
                      if (_uid != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FollowersScreen(userId: _uid),
                          ),
                        );
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildStatItem(
                    title: 'Following',
                    value: followingCount.toString(),
                    icon: Icons.person_add,
                    onTap: () {
                      if (_uid != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FollowingScreen(userId: _uid),
                          ),
                        );
                      }
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

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: _textLight.withOpacity(0.2));
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
              begin: Offset(_selectedTab == 0 ? 0.1 : -0.1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: _uid)
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
                final post = posts[index].data() as Map<String, dynamic>;
                final imageBase64 = post['image'] as String?;

                // Memperbaiki konversi timestamp
                DateTime createdAt;
                if (post['createdAt'] is Timestamp) {
                  createdAt = (post['createdAt'] as Timestamp).toDate();
                } else if (post['createdAt'] is String) {
                  createdAt = DateTime.parse(post['createdAt']);
                } else {
                  createdAt =
                      DateTime.now(); // fallback jika format tidak sesuai
                }

                return FadeInUp(
                  delay: Duration(milliseconds: index * 50),
                  duration: const Duration(milliseconds: 500),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => DetailScreen(
                                post: posts[index],
                                postId: posts[index].id,
                                imageBase64: imageBase64 ?? '',
                                description: post['description'] ?? '',
                                createdAt: createdAt,
                                fullName: post['fullName'] ?? 'Anonymous',
                                latitude: post['latitude'] ?? 0.0,
                                longitude: post['longitude'] ?? 0.0,
                                category: post['category'] ?? 'Uncategorized',
                                heroTag: 'post_${posts[index].id}',
                              ),
                        ),
                      );
                    },
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
                                          size: 32,
                                        ),
                                      ),
                                )
                                : Container(
                                  color: _card,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: _textDark.withOpacity(0.3),
                                    size: 32,
                                  ),
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
    if (_uid == null) return _buildEmptyState("User not identified.");

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .where('likedBy', arrayContains: _uid)
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
                            createdAt =
                                (post['createdAt'] as Timestamp).toDate();
                          } else if (post['createdAt'] is String) {
                            createdAt = DateTime.parse(post['createdAt']);
                          } else {
                            createdAt = DateTime.now();
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => DetailScreen(
                                    post: posts[index],
                                    postId: posts[index].id,
                                    imageBase64: imageBase64 ?? '',
                                    description: post['description'] ?? '',
                                    createdAt: createdAt,
                                    fullName: post['fullName'] ?? 'Anonymous',
                                    latitude: post['latitude'] ?? 0.0,
                                    longitude: post['longitude'] ?? 0.0,
                                    category:
                                        post['category'] ?? 'Uncategorized',
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

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap();
          }
        },
        borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _background,
            title: Text('Settings', style: TextStyle(color: _textLight)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<ThemeProvider>(
                  builder:
                      (context, themeProvider, child) => ListTile(
                        leading: Icon(
                          themeProvider.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: _textLight,
                        ),
                        title: Text(
                          'Dark Mode',
                          style: TextStyle(color: _textLight),
                        ),
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                          activeColor: _accent,
                        ),
                      ),
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: _textLight),
                  title: Text('Logout', style: TextStyle(color: _textLight)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            backgroundColor: _background,
                            title: Text(
                              'Confirm Logout',
                              style: TextStyle(color: _textLight),
                            ),
                            content: Text(
                              'Are you sure you want to logout? This will clear your local session.',
                              style: TextStyle(color: _textLight),
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: _accent),
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );

                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const SignInScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(color: _accent)),
              ),
            ],
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
  late Color _textDark;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    _card = isDark ? Colors.grey[850]! : const Color(0xFFEFEFEF);
    _textDark = isDark ? Colors.black87 : Colors.white;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageBase64 = widget.post['image'] as String?;

    return FadeInUp(
      delay: Duration(milliseconds: widget.index * 50),
      duration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _controller.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _controller.reverse();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      _isHovered
                          ? Colors.black.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                  blurRadius: _isHovered ? 15 : 10,
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
                    // Handle post tap - you can add navigation to detail screen here
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageBase64 != null && imageBase64.isNotEmpty)
                        AspectRatio(
                          aspectRatio: 1,
                          child: Image.memory(
                            base64Decode(imageBase64),
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  color: _card,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: _textDark.withOpacity(0.3),
                                  ),
                                ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post['description'] ?? '',
                                style: GoogleFonts.poppins(
                                  color: _textDark,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.getTimeAgo(widget.timestamp),
                                    style: GoogleFonts.poppins(
                                      color: _textDark.withOpacity(0.6),
                                      fontSize: 10,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.favorite_border,
                                        size: 16,
                                        color: _textDark.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        (widget.post['likes'] ?? 0).toString(),
                                        style: GoogleFonts.poppins(
                                          color: _textDark.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
