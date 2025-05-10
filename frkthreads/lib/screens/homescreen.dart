// homescreen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frkthreads/screens/postdetailscreen.dart';
import 'package:intl/intl.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const Color _background = Color(0xFF2D3B3A);
  static const Color _appBarColor = Color(0xFFB88C66);
  static const Color _iconColor = Color(0xFF2D3B3A);
  static const Color _fabColor = Color(0xFF2D3B3A);
  static const Color _bottomBarColor = Color(0xFFB88C66);
  static const Color _selectedItemColor = Colors.black;
  static const Color _unselectedItemColor = Colors.black54;

  final List<Widget> _widgetOptions = [
    const PostListView(),
    const SearchScreen(),
    NotificationScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _appBarColor,
        title: const Text(
          'FRKTHREADS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: const [
          Icon(Icons.brightness_2, color: _iconColor),
          SizedBox(width: 10),
          CircleAvatar(backgroundColor: _iconColor, radius: 16),
          SizedBox(width: 10),
        ],
      ),
      body: _widgetOptions[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        backgroundColor: _fabColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPostScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: _bottomBarColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.05,// Set a fixed height for the BottomAppBar
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: _selectedItemColor,
            unselectedItemColor: _unselectedItemColor,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications),
                label: 'Notifications',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostListView extends StatelessWidget {
  const PostListView({super.key});

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return '${diff.inSeconds} detik yang lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari yang lalu';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final posts = snapshot.data!.docs;

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final data = posts[index].data() as Map<String, dynamic>;
            final imageBase64 = data['image'] ?? '';
            final description = data['description'] ?? '';
            final createdAtRaw = data['createdAt'];
            final fullName = data['fullName'] ?? 'Anonim';
            final latitude = data['latitude'] ?? 0.0;
            final longitude = data['longitude'] ?? 0.0;
            final category = data['category'] ?? 'Tidak diketahui';

            DateTime createdAt;
            if (createdAtRaw is Timestamp) {
              createdAt = createdAtRaw.toDate();
            } else if (createdAtRaw is String) {
              createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
            } else {
              createdAt = DateTime.now();
            }

<<<<<<< Updated upstream
            return Card(
              margin: const EdgeInsets.all(10),
              color: Colors.white, // Using the consistent card color.
              elevation: 2, // Added a small elevation for better appearance
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageBase64 != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: Image.memory(
                        base64Decode(imageBase64),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
=======
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => DetailScreen(
                          imageBase64: imageBase64,
                          description: description,
                          createdAt: createdAt,
                          fullName: fullName,
                          latitude: latitude,
                          longitude: longitude,
                          category: category,
                          heroTag: 'post_$index',
                          postId: posts[index].id,
                        ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.all(10),
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageBase64.isNotEmpty)
                      Hero(
                        tag: 'post_$index',
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
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatTime(createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.thumb_up),
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('posts')
                                      .doc(posts[index].id)
                                      .update({
                                        'likes': FieldValue.increment(1),
                                      });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.comment),
                                onPressed: () {
                                  // Implement komentar jika perlu
                                },
                              ),
                            ],
                          ),
                        ],
>>>>>>> Stashed changes
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatTime(createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
