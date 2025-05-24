import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/models/story.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/screens/story_screen.dart';
import 'package:frkthreads/screens/add_story_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

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
        stream:
            FirebaseFirestore.instance
                .collection('stories')
                .where(
                  'createdAt',
                  isGreaterThan:
                      DateTime.now()
                          .subtract(const Duration(hours: 24))
                          .toUtc()
                          .millisecondsSinceEpoch,
                )
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stories =
              snapshot.data!.docs
                  .map((doc) => Story.fromFirestore(doc))
                  .toList();

          final currentUser = FirebaseAuth.instance.currentUser;
          Story? userStory;
          try {
            userStory = stories.firstWhere(
              (story) => story.userId == currentUser?.uid,
            );
          } catch (_) {
            userStory = null;
          }

          final otherStories =
              stories
                  .where((story) => story.userId != currentUser?.uid)
                  .toList();

          if (stories.isEmpty) {
            // Instead of showing "No stories available", show only the add story button
            return ListView(
              scrollDirection: Axis.horizontal,
              children: [_buildAddStoryButton(context, isDark, null)],
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: otherStories.length + 1, // +1 for user story button
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAddStoryButton(context, isDark, userStory);
              }

              final story = stories[index - 1];
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
                          border: Border.all(
                            color: isViewed ? Colors.grey : Colors.green,
                            width: 3,
                          ),
                        ),

                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle),
                          child: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              story.imageUrl,
                            ),
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
                      Text(
                        timeago.format(story.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
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

  Widget _buildAddStoryButton(
    BuildContext context,
    bool isDark,
    Story? userStory,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (userStory == null) {
                _addStory(context);
              } else {
                _showStory(context, [userStory], 0);
              }
            },
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    userStory == null
                        ? (isDark ? Colors.grey[800] : Colors.grey[200])
                        : Colors.red,
              ),
              child:
                  userStory == null
                      ? Icon(
                        Icons.add,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                      : CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          userStory.imageUrl,
                        ),
                      ),
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
        builder:
            (context) => StoryScreen(
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
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                const AddStoryScreen(isFromCamera: true),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                const AddStoryScreen(isFromCamera: false),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }
}
