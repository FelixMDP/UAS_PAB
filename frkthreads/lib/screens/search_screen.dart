import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frkthreads/screens/userprofilescreen.dart'; // Pastikan import ini benar
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
// import 'package:frkthreads/screens/detail_screen.dart'; // Tidak digunakan di kode ini

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  // final _currentUserId = FirebaseAuth.instance.currentUser?.uid; // Tidak digunakan di _searchUsers versi ini
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  // HAPUS BARIS INI KARENA TIDAK DIGUNAKAN DAN DIBAYANGI OLEH VARIABEL LOKAL:
  // get imageBytes => null;

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
          await FirebaseFirestore.instance.collection('users').get(); // Sudah benar 'users'

      final String lowerCaseQuery = query.toLowerCase();
      final filteredDocs = result.docs.where((doc) {
        // Filter agar pengguna saat ini tidak muncul di hasil pencarian (opsional, jika diinginkan)
        // if (doc.id == _currentUserId) {
        //   return false;
        // }
        final fullName =
            (doc.data() as Map<String, dynamic>)['fullName'] as String? ?? '';
        return fullName.toLowerCase().contains(lowerCaseQuery);
      }).toList();

      setState(() {
        _searchResults = filteredDocs;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) { // Tambahkan pengecekan mounted
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error searching users: $error')));
      }
    }
  }

  // Fungsi _viewUserProfile sudah tidak ada, digantikan navigasi langsung ke UserProfileScreen
  // Ini adalah perubahan yang baik dan menyederhanakan SearchScreen.

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
                            final userData = _searchResults[index].data()
                                as Map<String, dynamic>;
                            final fullName =
                                userData['fullName'] as String? ?? 'Anonymous';
                            final bio = userData['bio'] as String? ?? 'No bio yet';
                            final profileImageBase64 =
                                userData['profileImage'] as String?; // Pastikan field 'profileImage' ada di Firestore
                            final initialLetter = fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : '?';
                            final String userId = _searchResults[index].id; // Untuk logging dan navigasi

                            // Debug print untuk melihat data
                            print("--- Rendering User: $fullName (ID: $userId) ---");
                            print("profileImageBase64: ${profileImageBase64?.substring(0, (profileImageBase64.length > 30 ? 30 : profileImageBase64.length))}..."); // Cetak sebagian kecil saja
                            print("initialLetter: $initialLetter");


                            return ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                      userId: userId, // Menggunakan userId yang sudah diambil
                                    ),
                                  ),
                                );
                              },
                              leading: Builder( // Menggunakan Builder untuk logika avatar
                                builder: (BuildContext _) { // Memberi nama parameter jika tidak digunakan
                                  Uint8List? imageBytes;
                                  String? effectiveBase64 = profileImageBase64;

                                  if (effectiveBase64 != null && effectiveBase64.isNotEmpty) {
                                    // Membersihkan prefix data URI jika ada
                                    if (effectiveBase64.startsWith('data:image')) {
                                      effectiveBase64 = effectiveBase64.substring(effectiveBase64.indexOf(',') + 1);
                                      print("Base64 prefix removed for user: $fullName");
                                    }
                                    try {
                                      imageBytes = base64Decode(effectiveBase64);
                                    } catch (e) {
                                      debugPrint(
                                          'Invalid base64 profile image for $fullName (ID: $userId): $e');
                                      imageBytes = null; // Pastikan imageBytes null jika decode gagal
                                    }
                                  }

                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isDark
                                        ? Colors.grey[700]
                                        : Colors.white.withOpacity(0.7),
                                    child: imageBytes != null
                                        ? ClipOval(
                                            child: Image.memory(
                                              imageBytes,
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                // Fallback jika Image.memory gagal render bytes (meskipun base64 valid)
                                                debugPrint('Error rendering image memory for $fullName (ID: $userId): $error');
                                                return Text(
                                                  initialLetter,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              },
                                            ),
                                          )
                                        : Text( // Fallback jika imageBytes null
                                            initialLetter,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
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