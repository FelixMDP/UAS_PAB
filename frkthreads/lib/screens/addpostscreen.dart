import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:frkthreads/screens/homescreen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> with SingleTickerProviderStateMixin {
  File? _image;
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  bool _isUploading = false;
  bool _isGeneratingCategory = false;
  String? _base64Image;
  String? _aiCategory;
  double _latitude = 0.0;
  double _longitude = 0.0;
  Timer? _debounce;
  late final AnimationController _controller;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  late Color _background;
  late Color _accent;
  late Color _textLight;
  late Color _textDark;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeColors();
    _getLocation();
  }

  void _initializeColors() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    _updateColors(isDark);
  }

  void _updateColors(bool isDark) {
    _background = isDark ? const Color(0xFF2D3B3A) : const Color(0xFFF1E9D2);
    _accent = const Color(0xFFB88C66);
    _textLight = isDark ? Colors.white : const Color(0xFF293133);
    _textDark = isDark ? const Color(0xFF293133).withOpacity(0.7) : Colors.black87;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    _updateColors(themeProvider.isDarkMode);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _mapController?.dispose();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildGlassContainer({
    required Widget child,
    double height = 200,
    double borderRadius = 20,
    Color? overlayColor,
  }) {
    bool isCurrentlyDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isCurrentlyDark 
                ? Colors.black.withOpacity(0.2)
                : _accent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: overlayColor ?? (isCurrentlyDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.white.withOpacity(0.8)),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isCurrentlyDark 
                    ? Colors.white.withOpacity(0.15)
                    : _accent.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _aiCategory = null;
          // Do not clear description on image pick to avoid losing user input
          // _descriptionController.clear();
        });
        await _compressAndEncodeImage();
        final desc = _descriptionController.text.trim();
        if (desc.isNotEmpty) {
          await _generateCategoryFromDescription(desc);
        }
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
    if (_image == null) return;
    try {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _image!.path,
        quality: 50,
      );
      if (compressedImage == null) return;

      setState(() {
        _base64Image = base64Encode(compressedImage);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to compress image: $e')));
      }
    }
  }

  Future<void> _generateCategoryFromDescription(String description) async {
    setState(() => _isGeneratingCategory = true);
    try {
      final String apiKey = 'AIzaSyB_B3rjunORQJQKVLysNw7d80B8IgOsuCU';

      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);

      final prompt = '''
Berdasarkan deskripsi berikut, tentukan kategori konten ini. Hanya jawab dengan satu kata kategori saja seperti: makanan, hewan, perjalanan, aktivitas, hiburan, teknologi, dll.

Deskripsi: "$description"
Kategori:
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final result = response.text?.trim().toLowerCase();
      if (result != null && result.isNotEmpty) {
        setState(() {
          _aiCategory = result;
        });
      }
    } catch (e) {
      debugPrint('Failed to determine category: $e');
      setState(() {
        _aiCategory = null;
      });
    } finally {
      if (mounted) setState(() => _isGeneratingCategory = false);
    }
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint('Failed to retrieve location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retrieve location: $e')),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    if (_base64Image == null || _descriptionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add an image and description.')),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not found');
      }

      await _getLocation();

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final fullName = userDoc.data()?['fullName'] ?? 'Anonymous';
      final postData = {
        'image': _base64Image,
        'description': _descriptionController.text,
        'category': _aiCategory, // Will be null if no category is detected
        'createdAt': DateTime.now().toIso8601String(),
        'latitude': _latitude,
        'longitude': _longitude,
        'fullName': fullName,
        'userId': uid,
        'likes': 0,
        'likedBy': [],
        'comments': [],
        'commentDetails': [],
      };

      await FirebaseFirestore.instance.collection('posts').add(postData);

      if (!mounted) return;

      // Replace current screen with HomeScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post uploaded successfully!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _textLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt, color: _textLight),
                title: Text(
                  'Take a picture',
                  style: GoogleFonts.poppins(color: _textLight),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: _textLight),
                title: Text(
                  'Choose from gallery',
                  style: GoogleFonts.poppins(color: _textLight),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildMap() {
    return SizedBox(
      height: 200,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(_latitude, _longitude),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: LatLng(_latitude, _longitude),
          ),
        },
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentlyDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: isCurrentlyDark ? _background : _accent,
        elevation: 0,
        title: Text(
          'Create Post',
          style: GoogleFonts.poppins(
            color: isCurrentlyDark ? _textLight : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isCurrentlyDark ? _textLight : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Map Container with glass effect
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: _buildGlassContainer(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_latitude, _longitude),
                        zoom: 15,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image Container with glass effect
              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: _buildGlassContainer(
                    height: 250,
                    child: _image != null
                        ? Hero(
                            tag: 'previewImage',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                _image!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: _textLight.withOpacity(0.7),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Photo',
                                style: GoogleFonts.poppins(
                                  color: _textLight.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description Input with glass effect
              FadeInDown(
                delay: const Duration(milliseconds: 400),
                child: _buildGlassContainer(
                  height: 150,
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    style: GoogleFonts.poppins(
                      color: isCurrentlyDark ? _textLight : _textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts...',
                      hintStyle: GoogleFonts.poppins(
                        color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.7),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (text) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 1000), () {
                        _generateCategoryFromDescription(text);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category Display with glass effect
              if (_aiCategory != null || _isGeneratingCategory)
                FadeInDown(
                  delay: const Duration(milliseconds: 600),
                  child: _buildGlassContainer(
                    height: 50,
                    child: Center(
                      child: _isGeneratingCategory
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(_accent),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.label, color: _accent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _aiCategory ?? '',
                                  style: GoogleFonts.poppins(
                                    color: isCurrentlyDark ? _textLight : _textDark,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Submit Button
              FadeInDown(
                delay: const Duration(milliseconds: 800),
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Share Post',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
