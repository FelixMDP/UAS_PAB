import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddStoryScreen extends StatefulWidget {
  final bool isFromCamera;

  const AddStoryScreen({super.key, required this.isFromCamera});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  File? _imageFile;
  bool _isLoading = false;
  String? _base64Image;

  @override
  void initState() {
    super.initState();
    _pickImage();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: widget.isFromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _compressAndEncodeImage();
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
      if (mounted) {
        Navigator.pop(context);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to compress image: $e')),
        );
      }
    }
  }

  Future<void> _uploadStory() async {
    if (_base64Image == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add an image.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
      // Handle jika user tidak login
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('User not logged in.')),
         );
         setState(() => _isLoading = false);
      }
       return;
      }

      final storyData = {
      'userId': currentUser.uid,
      'userName': currentUser.displayName ?? 'Anonymous',
      'imageBase64': _base64Image, // Anda sudah menyimpan ini
      'createdAt': Timestamp.now(),
      'viewedBy': [],
      'durationInSeconds': 5, // <-- TAMBAHKAN INI (misalnya default 5 detik)
    };

      await FirebaseFirestore.instance.collection('stories').add(storyData);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story uploaded successfully!')),
      );
    } 
    catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading story: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _deleteImage() {
    setState(() {
      _imageFile = null;
      _base64Image = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2),
      appBar: AppBar(
        backgroundColor: _imageFile != null
            ? Colors.transparent
            : (isDark ? Colors.grey[900] : const Color(0xFFB88C66)),
        elevation: _imageFile != null ? 0 : 4,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Colors.white,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _imageFile != null
            ? const Text('')
            : const Text(
                'New Story',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          if (_imageFile != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _uploadStory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? Colors.blue[700] : const Color(0xFF2D3A3A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.send, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: _isLoading ? null : _deleteImage,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? Colors.white : const Color(0xFFB88C66),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading your story...',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _imageFile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 64,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select an image to share',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
    );
  }
}
