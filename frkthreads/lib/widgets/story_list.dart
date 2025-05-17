import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/models/story.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/screens/story_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryList extends StatelessWidget {
  const StoryList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .where('createdAt',
                isGreaterThan: DateTime.now()
                    .subtract(const Duration(hours: 24))
                    .toUtc()
                    .millisecondsSinceEpoch)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stories = snapshot.data!.docs
              .map((doc) => Story.fromFirestore(doc))
              .toList();

          if (stories.isEmpty) {
            return Center(
              child: Text(
                'No stories available',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: stories.length + 1, // +1 for add story button
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAddStoryButton(context, isDark);
              }

              final story = stories[index - 1];
              final currentUser = FirebaseAuth.instance.currentUser;
              final isViewed = story.isViewed(currentUser?.uid ?? '');

              return GestureDetector(
                onTap: () => _showStory(context, stories, index - 1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isViewed
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF833AB4),
                                    Color(0xFFF77737),
                                    Color(0xFFE1306C),
                                  ],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                          color: isViewed ? Colors.grey : null,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF293133)
                                  : const Color(0xFFF1E9D2),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundImage:
                                CachedNetworkImageProvider(story.imageUrl),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        story.userName.length > 10
                            ? '${story.userName.substring(0, 7)}...'
                            : story.userName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              color: isDark ? Colors.white : Colors.black87,
              onPressed: () => _addStory(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Story',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showStory(BuildContext context, List<Story> stories, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryScreen(
          story: stories[initialIndex],
          onComplete: () {
            if (initialIndex < stories.length - 1) {
              _showStory(context, stories, initialIndex + 1);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  void _addStory(BuildContext context) {
    // TODO: Implement story creation
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                // TODO: Implement camera capture
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                // TODO: Implement gallery picker
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
