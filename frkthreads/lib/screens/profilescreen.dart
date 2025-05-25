import 'dart:convert'; // Diperlukan untuk base64Decode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frkthreads/screens/editprofilescreen.dart';
import 'package:frkthreads/screens/settingscreen.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (_uid == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
        body: const Center(
          child: Text('User not logged in.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                    isDark ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data?.data() == null) {
              return Center(
                child: Text(
                  'User data not found. Try editing your profile.', // Pesan lebih informatif
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  textAlign: TextAlign.center,
                )
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final fullName = (data['fullName'] as String?)?.isNotEmpty == true
                ? data['fullName'] as String
                : (FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous');
            final bio = data['bio'] as String? ?? 'No bio yet';

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor:
                      isDark ? Colors.grey[900] : const Color(0xFFB88C66),
                  expandedHeight: 120,
                  toolbarHeight: 80,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsetsDirectional.only(start: 0, bottom: 16, end: 0),
                    centerTitle: true,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 16),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(8),
                            color: isDark ? Colors.grey[800] : Colors.white,
                          ),
                          child: data['profileImage'] != null && (data['profileImage'] as String).isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(data['profileImage']!),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => 
                                      Icon(Icons.person, size: 30, color: isDark ? Colors.white70: Colors.grey[600]),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFFB88C66),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                fullName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  shadows: const [Shadow(blurRadius: 1.0, color: Colors.black26)]
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                bio,
                                style: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                         const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isDark ? Colors.grey[800] : Colors.white,
                                  foregroundColor: isDark
                                      ? Colors.white
                                      : const Color(0xFFB88C66),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
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
                                child: const Text('Edit Profile'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.blue[700]
                                      : const Color(0xFF2D3B3A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Settings'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildTabSection(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 0), // Dihilangkan margin horizontal agar full width
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12), // Disesuaikan dengan style
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12), // Disesuaikan
                color: isDark ? Colors.blue[700] : const Color(0xFFB88C66),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[600],
              tabs: const [Tab(text: 'Posts'), Tab(text: 'Liked')],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: TabBarView(
              children: [_buildPostsGrid(), _buildLikedPostsGrid()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
    if (_uid == null) return _buildEmptyState("User not identified.");
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           return _buildEmptyState("No posts yet");
        }

        final posts = snapshot.data!.docs;
        return _buildGrid(posts);
      },
    );
  }

  Widget _buildLikedPostsGrid() {
    if (_uid == null) return _buildEmptyState("User not identified.");
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
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
        return _buildGrid(posts);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 50, // Ukuran disesuaikan
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[600], // Warna disesuaikan
              fontSize: 14, // Ukuran disesuaikan
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<DocumentSnapshot> posts) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final data = posts[index].data() as Map<String, dynamic>;
        final imageBase64 = data['image'] as String?;

        return Card(
          elevation: isDark ? 1 : 2,
          color: isDark ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          clipBehavior: Clip.antiAlias,
          child: imageBase64 != null && imageBase64.isNotEmpty
              ? Image.memory(
                  base64Decode(imageBase64), 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(
                      Icons.broken_image, 
                      color: isDark ? Colors.white38: Colors.grey,
                    ),
                  ),
                )
              : Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(
                    Icons.image_not_supported,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
        );
      },
    );
  }
}