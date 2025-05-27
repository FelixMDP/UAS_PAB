import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/screens/detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all users and filter them locally for case-insensitive search
      final QuerySnapshot result =
          await FirebaseFirestore.instance.collection('users').get();

      final filteredDocs =
          result.docs.where((doc) {
            final fullName =
                (doc.data() as Map<String, dynamic>)['fullName'] as String? ??
                '';
            return fullName.toLowerCase().contains(query.toLowerCase());
          }).toList();

      setState(() {
        _searchResults = filteredDocs;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching users: $error')));
    }
  }

  void _viewUserProfile(BuildContext context, DocumentSnapshot userDoc) async {
    // Get user's posts
    final postsSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: userDoc.id)
        .orderBy('createdAt', descending: true)
        .get();

    if (!mounted) return;

    // Show bottom sheet with user's posts
    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final data = userDoc.data() as Map<String, dynamic>;
          final fullName = data['fullName'] as String? ?? 'Anonymous';
          final bio = data['bio'] as String? ?? 'No bio yet';
          final profileImage = data['profileImage'] as String?;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        child: profileImage != null
                            ? ClipOval(
                                child: Image.memory(
                                  base64Decode(profileImage),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                fullName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                            Text(
                              bio,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: postsSnapshot.docs.isEmpty
                      ? const Center(
                          child: Text('No posts yet'),
                        )
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(2),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: postsSnapshot.docs.length,
                          itemBuilder: (context, index) {
                            final post = postsSnapshot.docs[index];
                            final postData = post.data();
                            final imageBase64 = postData['image'] as String?;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(post: post),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  image: imageBase64 != null
                                      ? DecorationImage(
                                          image: MemoryImage(
                                            base64Decode(imageBase64),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: imageBase64 == null
                                    ? const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _searchUsers,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Search for users'
                                : 'No users found',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            // ... (kode Anda yang lain di dalam itemBuilder ListView.builder)

final userData = _searchResults[index].data()
    as Map<String, dynamic>;
final fullName =
    userData['fullName'] as String? ?? 'Anonymous';
final bio = userData['bio'] as String? ?? 'No bio yet';
final profileImageBase64 =
    userData['profileImage'] as String?;
    final initialLetter = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    

return ListTile(
  onTap: () => _viewUserProfile(context, _searchResults[index]),
  leading: Builder(
    builder: (_) {
      Uint8List? imageBytes;
      if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
        try {
          imageBytes = base64Decode(profileImageBase64);
        } catch (e) {
          debugPrint('Invalid base64 profile image: $e');
        }
      }

      return CircleAvatar(
        radius: 18,
        backgroundColor: isDark ? Colors.grey[700] : Colors.white.withOpacity(0.7),
        child: imageBytes != null
            ? ClipOval(
                child: Image.memory(
                  imageBytes,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              )
            : Text(
                initialLetter,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
      );
    },
  ),
  title: Text(
    fullName,
    style: TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontWeight: FontWeight.bold,
    ),
  ),
  subtitle: Text(
    bio,
    style: TextStyle(
      color: isDark ? Colors.white60 : Colors.black54,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
);


                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
