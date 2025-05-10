import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
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
        pageBuilder: (context, animation, secondaryAnimation) => const SignInScreen(),
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
      backgroundColor: isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFB88C66),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isDark 
                ? [Colors.white, Colors.white70]
                : [Colors.white, Colors.white.withOpacity(0.8)],
          ).createShader(bounds),
          child: const Text(
            'FRKTHREADS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
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
              PageRouteBuilder(              pageBuilder: (context, animation, secondaryAnimation) =>
                    const AddPostScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.5, end: 1.0)
                          .animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
        color: isDark ? Colors.grey[900]! : const Color(0xFFB88C66),
        buttonBackgroundColor: isDark ? Colors.blue[700] : const Color(0xFF2D3B3A),
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
            color: _selectedIndex == 0
                ? Colors.white
                : isDark
                    ? Colors.white70
                    : Colors.white,
          ),
          Icon(
            Icons.search_rounded,
            size: 30,
            color: _selectedIndex == 1
                ? Colors.white
                : isDark
                    ? Colors.white70
                    : Colors.white,
          ),
          const SizedBox(width: 30), // Placeholder for FAB
          Icon(
            Icons.notifications_rounded,
            size: 30,
            color: _selectedIndex == 2
                ? Colors.white
                : isDark
                    ? Colors.white70
                    : Colors.white,
          ),
          Icon(
            Icons.person_rounded,
            size: 30,
            color: _selectedIndex == 3
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return StreamBuilder(
      stream: FirebaseFirestore.instance
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
                            Hero(
                              tag: 'post_image_$index',
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
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isDark 
                                          ? Colors.grey[700] 
                                          : Colors.grey[200],
                                      radius: 20,
                                      child: Text(
                                        fullName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: isDark 
                                              ? Colors.white 
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark 
                                                ? Colors.white 
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          formatTime(createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark 
                                                ? Colors.grey[400] 
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark 
                                        ? Colors.grey[300] 
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.favorite_border,
                                        color: isDark 
                                            ? Colors.grey[400] 
                                            : Colors.grey[600],
                                      ),
                                      onPressed: () {},
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.comment_outlined,
                                        color: isDark 
                                            ? Colors.grey[400] 
                                            : Colors.grey[600],
                                      ),
                                      onPressed: () {},
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.share_outlined,
                                        color: isDark 
                                            ? Colors.grey[400] 
                                            : Colors.grey[600],
                                      ),
                                      onPressed: () {},
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
}
