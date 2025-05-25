import 'dart:async';
import 'dart:convert'; // <-- DITAMBAHKAN: Untuk base64Decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/models/story.dart'; // Pastikan model Story Anda memiliki imageBase64
import 'package:frkthreads/providers/theme_provider.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // Tidak lagi digunakan untuk gambar utama

class StoryScreen extends StatefulWidget {
  final Story story;
  final VoidCallback onComplete;

  const StoryScreen({Key? key, required this.story, required this.onComplete})
      : super(key: key);

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();

    // Pastikan widget.story.duration memiliki nilai yang valid
    // Jika durasi bisa 0 atau negatif, AnimationController akan error.
    // Anda bisa memberikan durasi default jika perlu di model atau di sini.
    final storyDuration = (widget.story.duration.inMilliseconds > 0)
        ? widget.story.duration
        : const Duration(seconds: 5); // Durasi default jika tidak valid

    _animationController = AnimationController(
      vsync: this,
      duration: storyDuration,
    );

    _timer = Timer(storyDuration, () {
      if (mounted) { // Cek apakah widget masih terpasang
        widget.onComplete();
      }
    });

    _animationController.forward();
    _markAsViewed();
  }

  Future<void> _markAsViewed() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || widget.story.id.isEmpty) return; // Tambah cek widget.story.id

    try {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(widget.story.id)
          .update({
        'viewedBy': FieldValue.arrayUnion([currentUser.uid]),
      });
    } catch (e) {
      if (mounted) {
        // Sebaiknya tidak menampilkan SnackBar untuk error minor seperti ini di StoryScreen
        // karena bisa mengganggu pengalaman pengguna. Cukup log errornya.
        print('Error marking story as viewed: $e');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error marking story as viewed: $e')),
        // );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) { // Diperluas area tap kiri
            // Tap pada bagian kiri layar (mundur atau keluar)
             if (mounted) widget.onComplete(); // Untuk saat ini onComplete akan menutup atau ke story berikutnya
          } else if (details.globalPosition.dx > screenWidth * 2 / 3) { // Diperluas area tap kanan
            // Tap pada bagian kanan layar (maju)
            if (_animationController.isCompleted) {
              if (mounted) widget.onComplete();
            } else {
              _animationController.forward(from: _animationController.value); // Selesaikan animasi saat ini
              // _timer.cancel(); // Timer akan selesai secara alami atau saat dispose
              // if (mounted) widget.onComplete(); // Pindah ke story berikutnya
            }
          } else {
            // Tap di tengah untuk pause/resume (opsional)
            if (_animationController.isAnimating) {
              _animationController.stop();
              _timer.cancel(); // Hentikan timer juga jika pause
            } else {
              // Hitung sisa durasi untuk timer baru
              final remainingMilliseconds = (_animationController.duration!.inMilliseconds * (1 - _animationController.value)).round();
              _timer = Timer(Duration(milliseconds: remainingMilliseconds), () {
                if (mounted) widget.onComplete();
              });
              _animationController.forward();
            }
          }
        },
        child: Stack(
          children: [
            Center( // Tambahkan Center agar gambar di tengah jika aspect ratio berbeda
              child: (widget.story.imageBase64 != null && widget.story.imageBase64!.isNotEmpty)
                  ? Image.memory( // <-- PERUBAHAN UTAMA DI SINI
                      base64Decode(widget.story.imageBase64!),
                      fit: BoxFit.contain, // BoxFit.contain agar seluruh gambar terlihat
                      gaplessPlayback: true, // Hindari flicker saat gambar baru dimuat (jika ada state change)
                      errorBuilder: (context, error, stackTrace) {
                        // Tampilan jika gagal decode base64 atau gambar corrupt
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.white54, size: 60),
                              SizedBox(height: 8),
                              Text("Can't load image", style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center( // Tampilan jika tidak ada imageBase64
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, color: Colors.white54, size: 60),
                          SizedBox(height: 8),
                          Text("Image not available", style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
            ),
            // UI Overlay (User Info, Progress Bar, Close Button)
            Positioned(
              top: 50, // Sesuaikan dengan status bar height jika perlu (SafeArea)
              left: 10,
              right: 10,
              child: Column(
                children: [
                  Row( // Progress bars
                    children: [ // Jika hanya satu story, hanya satu bar
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _animationController.value,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 2.5, // Ketebalan bar
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row( // User info dan close button
                    children: [
                      // Anda bisa menampilkan foto profil pengguna cerita jika ada URL nya di model Story
                      // CircleAvatar(radius: 16, backgroundImage: NetworkImage(widget.story.userProfileUrl ?? '')),
                      // SizedBox(width: 8),
                      Text(
                        widget.story.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 1.0, color: Colors.black54)]
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () {
                           if (mounted) Navigator.of(context).pop(); // Selalu keluar dari StoryScreen
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
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
}