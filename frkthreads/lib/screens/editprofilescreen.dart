
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fullNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _isSaving = false;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  String? _profileImageBase64; // Menyimpan gambar profil sebagai base64
  final ImagePicker _picker = ImagePicker();

  // Warna konsisten
  static const Color _darkBackground = Color(0xFF293133);
  static const Color _lightBackground = Color(0xFFF1E9D2);
  static const Color _darkAppBar = Color(0xFF1F2628); // Sedikit lebih gelap untuk appbar
  static const Color _lightAppBar = Color(0xFFB88C66);
  static const Color _darkText = Colors.white;
  static const Color _lightText = Color(0xFF293133);
  static const Color _darkAccent = Colors.blue; // Warna aksen untuk dark mode
  static const Color _lightAccent = Color(0xFF2D3B3A); // Warna aksen untuk light mode


  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_uid == null) return; // Jika tidak ada user, jangan lakukan apa-apa

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _fullNameCtrl.text = data['fullName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? ''; // Fallback ke displayName Auth
            _bioCtrl.text = data['bio'] ?? '';
            _profileImageBase64 = data['profileImage'] as String?;
          });
        }
      } else {
        // Jika dokumen user di Firestore belum ada, isi dengan displayName dari Auth jika ada
         setState(() {
            _fullNameCtrl.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
         });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_uid == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated. Cannot save profile.')),
      );
      return;
    }
    if (_fullNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name cannot be empty.')),
      );
      return;
    }


    setState(() => _isSaving = true);

    final newFullName = _fullNameCtrl.text.trim();

    try {
      // 1. Update displayName di Firebase Authentication
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.displayName != newFullName) {
        await currentUser.updateDisplayName(newFullName);
      }

      // 2. Update data di Firestore
      Map<String, dynamic> dataToUpdate = {
        'fullName': newFullName,
        'bio': _bioCtrl.text.trim(),
        // Hanya update profileImage jika ada perubahan atau sudah ada sebelumnya
        // Untuk menghapus, Anda bisa set ke null atau FieldValue.delete()
      };
      if (_profileImageBase64 != null) {
        dataToUpdate['profileImage'] = _profileImageBase64;
      } else {
        // Jika _profileImageBase64 null, mungkin Anda ingin menghapusnya dari Firestore
        dataToUpdate['profileImage'] = FieldValue.delete();
      }


      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .set(dataToUpdate, SetOptions(merge: true)); // Gunakan set dengan merge true untuk membuat dokumen jika belum ada / update

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Kualitas awal sebelum kompresi
        maxWidth: 800, // Batasi ukuran gambar
        maxHeight: 800,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        // Kompres gambar
        final compressedImage = await FlutterImageCompress.compressWithFile(
          file.absolute.path, // Gunakan absolute path
          quality: 50, // Kualitas setelah kompresi
          minWidth: 200, // Ukuran minimal setelah kompresi
          minHeight: 200,
        );
        if (compressedImage != null) {
          setState(() {
            _profileImageBase64 = base64Encode(compressedImage);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }
  

  void _showImageSourceDialog() {
     final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
     final isDark = themeProvider.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? _darkBackground : _lightBackground,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt, color: isDark ? _darkText.withOpacity(0.7) : _lightText.withOpacity(0.7)),
                title: Text('Take a picture', style: TextStyle(color: isDark ? _darkText : _lightText)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: isDark ? _darkText.withOpacity(0.7) : _lightText.withOpacity(0.7)),
                title: Text('Choose from gallery', style: TextStyle(color: isDark ? _darkText : _lightText)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImageBase64 != null) // Opsi untuk menghapus gambar
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red[400]),
                  title: Text('Remove profile picture', style: TextStyle(color: Colors.red[400])),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profileImageBase64 = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Tentukan warna berdasarkan tema
    final currentBackgroundColor = isDark ? _darkBackground : _lightBackground;
    final currentAppBarColor = isDark ? _darkAppBar : _lightAppBar;
    final currentTextColor = isDark ? _darkText : _lightText;
    final currentAccentColor = isDark ? _darkAccent : _lightAccent;
    final currentHintColor = isDark ? Colors.white54 : Colors.black54;


    return Scaffold(
      backgroundColor: currentBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(color: currentTextColor),
        ),
        backgroundColor: currentAppBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: currentTextColor), // Untuk tombol back
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: currentTextColor),
            onPressed: _isSaving ? null : _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _showImageSourceDialog,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                      child: _profileImageBase64 != null
                          ? ClipOval(
                              child: Image.memory(
                                base64Decode(_profileImageBase64!),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                  Icon(Icons.person, size: 60, color: currentHintColor),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 60,
                              color: currentHintColor,
                            ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: currentAccentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: currentBackgroundColor, width: 2)
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _fullNameCtrl,
              style: TextStyle(color: currentTextColor),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: currentHintColor),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: currentHintColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: currentAccentColor),
                ),
                filled: true,
                fillColor: isDark? Colors.grey[800] : Colors.white.withOpacity(0.8),
                prefixIcon: Icon(Icons.person_outline, color: currentHintColor),
              ),
               validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full name cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              maxLength: 150, // Batasi panjang bio
              style: TextStyle(color: currentTextColor, height: 1.5),
              decoration: InputDecoration(
                labelText: 'Bio',
                alignLabelWithHint: true,
                labelStyle: TextStyle(color: currentHintColor),
                hintText: 'Tell us something about yourself...',
                hintStyle: TextStyle(color: currentHintColor.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: currentHintColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: currentAccentColor),
                ),
                filled: true,
                fillColor: isDark? Colors.grey[800] : Colors.white.withOpacity(0.8),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28.0), // Sesuaikan padding ikon
                  child: Icon(Icons.edit_note_outlined, color: currentHintColor),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: _isSaving 
                  ? Container(
                      width: 20, 
                      height: 20, 
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                  : const Icon(Icons.save_alt_outlined, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Changes',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: currentAccentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}