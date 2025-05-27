import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/screens/userprofilescreen.dart';
import 'package:provider/provider.dart';

class FollowingScreen extends StatelessWidget {
  final String userId;

  const FollowingScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final backgroundColor =
        isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2);
    final textColor = isDark ? Colors.white : const Color(0xFF293133);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text('Following', style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final following = List<String>.from(userData?['following'] ?? []);

          if (following.isEmpty) {
            return Center(
              child: Text(
                'Not following anyone',
                style: TextStyle(color: textColor),
              ),
            );
          }

          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(following[index])
                        .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(title: Text('Loading...'));
                  }

                  final followingData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final profileImage = followingData['profileImage'] as String?;
                  final fullName =
                      followingData['fullName'] as String? ?? 'Anonymous';

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[200],
                      child:
                          profileImage != null && profileImage.isNotEmpty
                              ? ClipOval(
                                child: Image.memory(
                                  base64Decode(profileImage),
                                  fit: BoxFit.cover,
                                  width: 50,
                                  height: 50,
                                ),
                              )
                              : Icon(Icons.person, color: textColor),
                    ),
                    title: Text(
                      fullName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  UserProfileScreen(userId: following[index]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
