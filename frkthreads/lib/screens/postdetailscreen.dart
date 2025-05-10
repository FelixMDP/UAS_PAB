// detailscreen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'full_image_screen.dart';

class DetailScreen extends StatefulWidget {
  final String imageBase64;
  final String description;
  final DateTime createdAt;
  final String fullName;
  final double latitude;
  final double longitude;
  final String category;
  final String heroTag;
  final String postId;

  const DetailScreen({
    super.key,
    required this.imageBase64,
    required this.description,
    required this.createdAt,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.heroTag,
    required this.postId,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<String> comments = [];
  int likes = 0;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    _fetchPostDetails();
  }

  Future<void> _fetchPostDetails() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          comments = List<String>.from(data['comments'] ?? []);
          likes = data['likes'] ?? 0;
          isLiked = (data['likedBy'] ?? []).contains(
            FirebaseAuth.instance.currentUser?.uid,
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching post details: $e');
    }
  }

  Future<void> _toggleLike() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      final doc = await postRef.get();

      if (!doc.exists) return;

      final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);

      if (likedBy.contains(uid)) {
        likedBy.remove(uid);
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': likedBy,
        });
      } else {
        likedBy.add(uid);
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': likedBy,
        });
      }

      _fetchPostDetails();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
            'comments': FieldValue.arrayUnion([_commentController.text.trim()]),
          });

      _commentController.clear();
      _fetchPostDetails();
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  Future<void> openMap(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
    );
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka Google Maps')),
      );
    }
  }

  Widget _buildCommentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(comments[index], style: TextStyle(fontSize: 14)),
                leading: CircleAvatar(child: Icon(Icons.person)),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _addComment(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAtFormatted = DateFormat(
      'dd MMMM yyyy, HH:mm',
    ).format(widget.createdAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Postingan')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: widget.heroTag,
                  child: Image.memory(
                    base64Decode(widget.imageBase64),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => FullscreenImageScreen(
                                imageBase64: widget.imageBase64,
                              ),
                        ),
                      );
                    },
                    tooltip: 'Lihat gambar penuh',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category, size: 20, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        widget.category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => openMap(context),
                        icon: const Icon(
                          Icons.map,
                          size: 32,
                          color: Colors.lightGreen,
                        ),
                        tooltip: "Buka di Google Maps",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 20,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        createdAtFormatted,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : null,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text('$likes likes'),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.comment),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder:
                                (context) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Comments (${comments.length})',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildCommentSection(),
                                      ],
                                    ),
                                  ),
                                ),
                          );
                        },
                      ),
                      Text('${comments.length} comments'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
