// pubspec.yaml add these dependencies:
//   geolocator: ^9.0.2
//   google_maps_flutter: ^2.1.8
//   flutter_image_compress: ^1.1.1
//   image_picker: ^0.8.7+4
//   permission_handler: ^10.2.0

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({Key? key}) : super(key: key);

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  File? _image;
  String? _base64Image;
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  LatLng? _pickedLocation;

  static const Color _background = Color(0xFF2D3B3A);
  static const Color _accent = Color(0xFFB88C66);
  static const Color _card = Color(0xFFEFEFEF);

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      if (!await Permission.camera.request().isGranted) return;
    } else {
      if (!await Permission.photos.request().isGranted) return;
    }
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      final file = File(picked.path);
      final compressed = await FlutterImageCompress.compressWithFile(file.path, quality: 50);
      setState(() {
        _image = file;
        _base64Image = compressed != null ? base64Encode(compressed) : null;
      });
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _background,
        title: const Text('Choose Image Source', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.camera);
            },
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text('Camera', style: TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.gallery);
            },
            icon: const Icon(Icons.photo, color: Colors.white),
            label: const Text('Gallery', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLocation() async {
    if (!await Permission.locationWhenInUse.request().isGranted) return;
    final pos = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (pos != null) setState(() => _pickedLocation = pos);
  }

  Future<void> _submit() async {
    if (_base64Image == null || _captionController.text.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final now = DateTime.now().toIso8601String();
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      await FirebaseFirestore.instance.collection('posts').add({
        'image': _base64Image,
        'caption': _captionController.text,
        'createdAt': now,
        'location': _pickedLocation != null
            ? GeoPoint(_pickedLocation!.latitude, _pickedLocation!.longitude)
            : null,
        'userId': uid,
        'fullName': userDoc.data()?['fullName'] ?? 'Anonymous',
      });
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _isUploading ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: _isUploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Post', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  image: _image != null
                      ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                      : null,
                ),
                child: _image == null
                    ? const Center(child: Icon(Icons.add, size: 48, color: Colors.black26))
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Caption', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
            TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter caption',
                hintStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Location', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _selectLocation,
              style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Text(_pickedLocation == null ? 'Choose From Map' : 'Location Selected', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(color: _accent, shape: const CircularNotchedRectangle(), notchMargin: 6, child: const SizedBox(height: 56)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({Key? key}) : super(key: key);
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late GoogleMapController _mapController;
  LatLng? _selected;

  static const CameraPosition _initial = CameraPosition(target: LatLng(-6.200000, 106.816666), zoom: 12);

  void _onTap(LatLng pos) {
    setState(() => _selected = pos);
  }

  void _confirm() {
    if (_selected != null) Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: _initial,
        onMapCreated: (c) => _mapController = c,
        onTap: _onTap,
        markers: _selected != null ? {Marker(markerId: const MarkerId('sel'), position: _selected!)} : {},
      ),
    );
  }
}
