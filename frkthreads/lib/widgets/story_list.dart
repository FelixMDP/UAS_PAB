import 'dart:convert'; // <-- DITAMBAHKAN: Untuk base64Decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/models/story.dart'; // Pastikan model Story Anda memiliki 'imageBase64' dan 'isViewed'
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:frkthreads/screens/story_screen.dart';
import 'package:frkthreads/screens/add_story_screen.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // Tidak digunakan lagi jika pakai base64
import 'package:timeago/timeago.dart' as timeago;

class StoryList extends StatelessWidget {
  const StoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      height: 120, // Sedikit ditambah tingginya untuk mengakomodasi teks timeago
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .where(
              'createdAt', // Pastikan field 'createdAt' adalah Timestamp Firestore
              isGreaterThan: Timestamp.fromDate( // Lebih aman menggunakan Timestamp.fromDate
                  DateTime.now().subtract(const Duration(hours: 24))),
            )
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Tampilkan loading indicator jika koneksi aktif tapi belum ada data
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }

          // Jika tidak ada data sama sekali (setelah loading selesai)
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Tampilkan hanya tombol add story jika tidak ada cerita sama sekali
            return ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding( // Tambahkan padding agar tidak terlalu mepet
                  padding: const EdgeInsets.only(left: 8.0),
                  child: _buildAddStoryButton(context, isDark, null),
                )
              ],
            );
          }

          final allStories = snapshot.data!.docs
              .map((doc) => Story.fromFirestore(doc)) // Asumsi Story.fromFirestore mengisi imageBase64
              .toList();

          final currentUser = FirebaseAuth.instance.currentUser;
          Story? userStory;
          try {
            userStory = allStories.firstWhere(
              (story) => story.userId == currentUser?.uid,
            );
          } catch (_) {
            userStory = null;
          }

          final otherStories = allStories
              .where((story) => story.userId != currentUser?.uid)
              .toList();
          
          // Jika setelah filter 24 jam, hanya ada cerita pengguna atau tidak ada cerita lain
          if (otherStories.isEmpty && userStory == null) {
             return ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: _buildAddStoryButton(context, isDark, null),
                )
              ],
            );
          }


          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: otherStories.length + 1, // +1 for user story button
            itemBuilder: (context, index) {
              if (index == 0) {
                // Selalu tampilkan tombol cerita pengguna di awal
                return Padding( // Tambahkan padding agar tidak terlalu mepet
                  padding: const EdgeInsets.only(left: 8.0),
                  child: _buildAddStoryButton(context, isDark, userStory),
                );
              }

              // PERBAIKAN: Ambil cerita dari 'otherStories'
              final story = otherStories[index - 1];
              final isViewedByCurrentUser = story.isViewed(currentUser?.uid ?? ''); // Asumsi ada method isViewed di model Story

              return GestureDetector(
                onTap: () => _showStory(context, allStories, allStories.indexOf(story)), // Kirim allStories agar navigasi benar
                child: Container(
                  width: 80, // Beri lebar agar teks nama tidak terlalu sempit
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isViewedByCurrentUser
                                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400) // Warna berbeda jika sudah dilihat
                                : Colors.green, // Warna jika belum dilihat
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300], // Warna background default
                          // PERUBAHAN: Gunakan MemoryImage untuk base64
                          backgroundImage: story.imageBase64 != null && story.imageBase64!.isNotEmpty
                              ? MemoryImage(base64Decode(story.imageBase64!))
                              : null,
                          child: (story.imageBase64 == null || story.imageBase64!.isEmpty)
                              ? Text( // Tampilkan inisial jika tidak ada gambar
                                  story.userName.isNotEmpty ? story.userName[0].toUpperCase() : '?',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        story.userName.length > 8 // Sesuaikan panjang nama agar pas
                            ? '${story.userName.substring(0, 7)}...'
                            : story.userName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        // PERBAIKAN: Gunakan .toDate() untuk konversi Timestamp ke DateTime
                        timeago.format(story.createdAt.toDate(), locale: 'id'), // Tambahkan locale jika perlu (misal 'id' untuk Bahasa Indonesia)
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black54,
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
    Story? userStory, // Ini adalah cerita milik pengguna saat ini
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool hasUserStoryImage = userStory?.imageBase64 != null && userStory!.imageBase64!.isNotEmpty;

    return Container(
      width: 80, // Samakan lebar dengan item cerita lain
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (userStory == null) {
                _addStory(context); // Pengguna belum punya cerita, langsung ke halaman tambah
              } else {
                // Pengguna sudah punya cerita, tampilkan opsi
                showModalBottomSheet(
                  context: context,
                  backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: Icon(Icons.remove_red_eye, color: isDark ? Colors.white70 : Colors.black87),
                          title: Text('View your story', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          onTap: () {
                            Navigator.pop(context);
                            // Saat melihat cerita sendiri, kita bisa anggap itu satu-satunya cerita dalam list sementara
                            _showStory(context, [userStory], 0);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.add_circle_outline, color: isDark ? Colors.white70 : Colors.black87),
                          title: Text('Add to your story', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          onTap: () {
                            Navigator.pop(context);
                            _addStory(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(2), // Padding untuk border
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: userStory != null // Beri border jika ada cerita pengguna
                    ? Border.all(
                        color: Colors.blueAccent, // Warna border untuk cerita pengguna
                        width: 3,
                      )
                    : null, // Tidak ada border jika hanya tombol tambah
              ),
              child: CircleAvatar(
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                // PERUBAHAN: Gunakan MemoryImage untuk base64 jika ada userStory
                backgroundImage: hasUserStoryImage
                    ? MemoryImage(base64Decode(userStory.imageBase64!))
                    : null,
                child: !hasUserStoryImage // Tampilkan ikon tambah atau inisial
                    ? Icon(
                        Icons.add,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 30,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Story',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
           Text( // Tampilkan waktu cerita pengguna jika ada
            userStory != null ? timeago.format(userStory.createdAt.toDate(), locale: 'id') : '',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  void _showStory(BuildContext context, List<Story> storiesToView, int initialIndex) {
    if (initialIndex < 0 || initialIndex >= storiesToView.length) return; // Jaga-jaga

    Navigator.of(context).push(
      MaterialPageRoute(
        // PERBAIKAN: Menggunakan 'builder' bukan 'pageBuilder'
        builder: (ctx) => StoryScreen(
          story: storiesToView[initialIndex],
          onComplete: () {
            Navigator.of(ctx).pop(); // Tutup StoryScreen saat ini
            // Pindah ke cerita berikutnya JIKA ADA
            // dan jika ada lebih dari satu cerita yang sedang dilihat dalam grup ini
            if (storiesToView.length > 1 && initialIndex < storiesToView.length - 1) {
              // Pastikan kita tidak memanggil _showStory secara rekursif
              // jika StoryScreen yang baru juga akan memanggil onComplete untuk cerita berikutnya.
              // Cara yang lebih aman adalah StoryScreen sendiri yang mengelola navigasi ke story berikutnya
              // atau mengembalikan hasil yang menandakan untuk pindah ke story berikutnya.
              // Untuk sementara, jika Anda ingin berpindah otomatis:
              // _showStory(context, storiesToView, initialIndex + 1); 
              // Namun, ini bisa menyebabkan tumpukan halaman.
              // Pertimbangkan untuk membuat StoryScreen menampilkan semua storiesToView dan mengelola indeksnya secara internal.
            }
          },
        ),
      ),
    );
  }

  void _addStory(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: isDark ? Colors.white70 : Colors.black87),
              title: Text('Take Photo', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context); // Tutup modal sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AddStoryScreen(isFromCamera: true),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: isDark ? Colors.white70 : Colors.black87),
              title: Text('Choose from Gallery', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context); // Tutup modal sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
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