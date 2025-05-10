import 'package:flutter/material.dart';
import 'postscreen.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  // Color constants to match app theme
  static const Color _appBarColor = Color(0xFFB88C66);
  static const Color _background = Color(0xFF2D3B3A);

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Post Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _appBarColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(child: PostScreen(postId: postId)),
    );
  }
}
