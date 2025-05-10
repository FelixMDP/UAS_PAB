import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  static const Color _background = Color(0xFF2D3B3A);
  static const Color _accent = Color(0xFFB88C66);
  static const Color _card = Color(0xFFEFEFEF);
  static const Color _textLight = Colors.white;
  static const Color _textDark = Colors.black87;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: _textLight)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildTabSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final fullName = userData['fullName'] ?? 'Username';
        final bio = userData['bio'] ?? 'Bio';
        final photoUrl = userData['photoUrl'];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _card,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            color: _textLight,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          style: const TextStyle(
                            color: _textLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: _textDark,
                        backgroundColor: _card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                      },
                      child: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: _textDark,
                        backgroundColor: _card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      child: const Text('Setting'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabSection() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              labelColor: _background,
              unselectedLabelColor: _textLight,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              tabs: const [Tab(text: 'Threads'), Tab(text: 'Media')],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [_buildThreadsView(), _buildMediaView()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadsView() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: _uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No threads yet.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final caption = data['caption'] ?? '';
            return ListTile(
              leading: const Icon(Icons.circle, color: _textLight),
              title: Text(caption, style: const TextStyle(color: _textLight)),
            );
          },
        );
      },
    );
  }

  Widget _buildMediaView() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: _uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No media yet.', style: TextStyle(color: Colors.white)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final imageBase64 = data['image'] as String?;
            if (imageBase64 == null) return const SizedBox.shrink();
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(base64Decode(imageBase64), fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }
}

/// Screen untuk mengedit profil pengguna
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fullNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _isSaving = false;
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  File? _imageFile;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();
  String? _existingPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _fullNameCtrl.text = data['fullName'] ?? '';
          _bioCtrl.text = data['bio'] ?? '';
          _existingPhotoUrl = data['photoUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _compressAndEncodeImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _compressAndEncodeImage() async {
    if (_imageFile == null) return;
    try {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _imageFile!.path,
        quality: 50,
      );
      if (compressedImage == null) return;
      setState(() {
        _base64Image = base64Encode(compressedImage);
      });
    } catch (e) {
      debugPrint('Error compressing image: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadProfilePicture() async {
    try {
      if (_base64Image == null) return null;

      // Store the base64 image directly in user document
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'photoUrl': _base64Image,
      });

      return _base64Image;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      String? photoUrl = await _uploadProfilePicture();

      final updateData = {
        'fullName': _fullNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      };

      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update(updateData);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildProfileImage() {
    if (_imageFile != null) {
      return CircleAvatar(radius: 50, backgroundImage: FileImage(_imageFile!));
    } else if (_existingPhotoUrl != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(base64Decode(_existingPhotoUrl!)),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _showImageSourceDialog,
              ),
            ),
          ],
        ),
      );
    } else {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[300],
        child: IconButton(
          icon: const Icon(Icons.camera_alt, size: 30, color: Colors.grey),
          onPressed: _showImageSourceDialog,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: _buildProfileImage(),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _fullNameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              child:
                  _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen untuk pengaturan aplikasi
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/signin');
            },
          ),
          // Tambahkan opsi pengaturan lainnya di sini
        ],
      ),
    );
  }
}
