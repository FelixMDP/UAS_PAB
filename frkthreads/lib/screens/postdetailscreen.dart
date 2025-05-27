import 'dart:convert';
import 'dart:ui'; // Untuk ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk SystemUiOverlayStyle
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frkthreads/widgets/post_ui_components.dart'; // Pastikan path ini benar
import 'package:frkthreads/services/notification_service.dart'; // Pastikan path ini benar
// import 'package:animate_do/animate_do.dart'; // Tidak digunakan di file ini, bisa dihapus jika tidak ada rencana penggunaan
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';

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
  final DocumentSnapshot post;

  // Color palette statis bisa dihapus jika tidak digunakan secara global dari sini
  // static const Color _darkBackground = Color(0xFF2D3B3A);
  // static const Color _lightBackground = Color(0xFFF1E9D2);
  // static const Color _accent = Color(0xFFB88C66);

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
    required this.post,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Color _background;
  late Color _accent;
  late Color _textLight;
  late Color _textDark; // Perhatikan penggunaan warna ini

  final TextEditingController _commentController = TextEditingController();
  late StreamSubscription<DocumentSnapshot> _postSubscription;
  // List<String> comments = []; // Tidak digunakan lagi karena ada commentDetails
  List<Map<String, dynamic>> commentDetails = [];
  int likes = 0;
  bool isLiked = false;
  Timer? _timer;
  String _timeAgo = '';
  bool isPostOwner = false;
  bool _isLiking = false;
  bool _isCommenting = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi warna di initState juga, agar tersedia sebelum build pertama
    // dan akan diupdate oleh didChangeDependencies jika tema berubah saat widget aktif
    _initializeColors(); 
    _fetchPostDetails();
    _updateTimeAgo();
    _checkPostOwnership();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) { // Cek mounted sebelum setState di timer
        _updateTimeAgo();
      }
    });
  }

  void _initializeColors() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false); // listen: false di initState
    final isDark = themeProvider.isDarkMode;
    _updateColors(isDark);
  }

  void _updateColors(bool isDark) {
    _background = isDark ? const Color(0xFF2D3B3A) : const Color(0xFFF1E9D2);
    _accent = const Color(0xFFB88C66); // Accent color tetap
    _textLight = isDark ? Colors.white : const Color(0xFF293133); // Teks utama untuk kontras
    // _textDark mungkin perlu penyesuaian definisi atau penggunaan:
    // Saat ini: Teks gelap di mode gelap, teks putih di mode terang.
    // Seharusnya mungkin: Teks gelap untuk mode terang, dan teks lebih gelap lagi (atau sama dengan _textLight) di mode gelap.
    // Untuk sekarang, kita biarkan sesuai definisi user, tapi ini area yang bisa direview.
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
    _commentController.dispose();
    _timer?.cancel();
    _postSubscription.cancel();
    super.dispose();
  }

  void _updateTimeAgo() {
    setState(() {
      _timeAgo = _formatTimeAgo(widget.createdAt);
    });
  }

  void _checkPostOwnership() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      // Ambil userId dari widget.post dengan aman
      final postData = widget.post.data() as Map<String, dynamic>?;
      final postUserId = postData?['userId'] as String?;
      if (postUserId != null) {
        setState(() {
          isPostOwner = postUserId == currentUserId;
        });
      }
    }
  }

  Future<void> _fetchPostDetails() async {
    _postSubscription = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data()!; // Aman karena doc.exists sudah dicek
        setState(() {
          // comments = List<String>.from(data['comments'] ?? []); // Tidak digunakan
          commentDetails = List<Map<String, dynamic>>.from(
            data['commentDetails'] ?? [],
          );
          likes = data['likes'] ?? 0;
          isLiked = (data['likedBy'] as List<dynamic>? ?? []) // Cast ke List<dynamic> dulu
              .contains(FirebaseAuth.instance.currentUser?.uid);
        });
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    try {
      setState(() => _isLiking = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLiking = false);
        return;
      }

      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      
      if (isLiked) {
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
        });
      } else {
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([uid]),
        });
      }
    } catch (e) {
      _showErrorSnackBar('Could not update like status: $e');
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _addComment() async {
    if (_isCommenting) return;
    
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      setState(() => _isCommenting = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Please sign in to comment');
        if (mounted) setState(() => _isCommenting = false); // Kembalikan state jika user null
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final postData = widget.post.data() as Map<String, dynamic>?; // Ambil data post dengan aman
      final postOwnerId = postData?['userId'] as String?;

      final userName = userDoc.data()?['fullName'] as String? ?? user.displayName ?? 'Anonymous';

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
        // 'comments': FieldValue.arrayUnion([commentText]), // Tidak digunakan lagi, diganti commentDetails
        'commentDetails': FieldValue.arrayUnion([
          {
            'userId': user.uid,
            'userName': userName,
            'text': commentText,
            'timestamp': Timestamp.now(),
          }
        ]),
      });

      _commentController.clear();
      
      if (postOwnerId != null && user.uid != postOwnerId) {      
        NotificationService.instance.createNotification(
          type: 'comment',
          toUserId: postOwnerId,
          postId: widget.postId,
          description: '$userName commented on your post',
        );
      }
      // Pindahkan pesan sukses ke sini, setelah semua operasi di try berhasil
      if (mounted) {
         _showMessage('Comment added successfully');
      }

    } catch (e) {
      _showErrorSnackBar('Could not add comment: $e');
    } finally {      
      if (mounted) {
        setState(() => _isCommenting = false);
      }
    }
  }

  Future<void> _deletePost() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();
      
      if (mounted) {
        Navigator.pop(context); // Kembali setelah berhasil delete
        _showMessage('Post deleted successfully');
      }
    } catch (e) {
      _showErrorSnackBar('Could not delete post: $e');
    }
  }

  // IMPLEMENTASI _showDeleteConfirmation
  void _showDeleteConfirmation() {
    // Warna sudah diinisialisasi di _DetailScreenState (_background, _textLight, _accent)
    // dan akan diupdate oleh didChangeDependencies
    showDialog(
      context: context, // Menggunakan context dari _DetailScreenState
      builder: (BuildContext dialogContext) { // Menggunakan dialogContext untuk Navigator.pop
        return AlertDialog(
          backgroundColor: _background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Post?',
            style: GoogleFonts.poppins(color: _textLight, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: GoogleFonts.poppins(color: _textLight.withOpacity(0.8)),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins(color: _accent, fontWeight: FontWeight.w500)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deletePost();
              },
            ),
          ],
        );
      },
    );
  }


  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) { // Lebih presisi untuk di bawah 1 menit
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: _accent, // Menggunakan _accent state
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        // animation property tidak ada di SnackBar, bisa dihapus
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    required double height,
    double borderRadius = 16,
  }) {
    // final themeProvider = Provider.of<ThemeProvider>(context); // Sudah ada di didChangeDependencies
    // final isDark = themeProvider.isDarkMode; // isDark bisa diambil dari state class jika perlu
    // atau gunakan _background yang sudah diupdate

    bool isCurrentlyDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;


    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isCurrentlyDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isCurrentlyDark 
                ? Colors.black.withOpacity(0.2)
                : _accent.withOpacity(0.1), // Menggunakan _accent state
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
              color: Colors.transparent, // Glass effect needs transparent internal color
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isCurrentlyDark 
                    ? Colors.white.withOpacity(0.15)
                    : _accent.withOpacity(0.2), // Menggunakan _accent state
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // IMPLEMENTASI _openMap (menggantikan logika di _showMapBottomSheet onTap)
  Future<void> _openMap() async {
  final double lat = widget.latitude;
  final double lon = widget.longitude;
  // Encode label agar aman digunakan di URL
  final String encodedLabel = Uri.encodeComponent(
      widget.description.isNotEmpty ? widget.description : 'Post Location');

  // Opsi 1: Skema URI 'geo' (mencoba membuka aplikasi peta default)
  // Format: geo:latitude,longitude?q=latitude,longitude(Label)
  final Uri geoUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon($encodedLabel)');

  // Opsi 2: URL web Google Maps (dibuka di browser atau aplikasi peta jika bisa menanganinya)
  // Format: https://www.google.com/maps/@${latitude},{longitude},{zoom}z
  // Anda bisa menyesuaikan level zoom (misalnya 15z)
  final Uri webUri = Uri.parse('https://www.google.com/maps/@$lat,$lon,15z');

  // Coba luncurkan dengan geoUri terlebih dahulu
  if (await canLaunchUrl(geoUri)) {
    await launchUrl(geoUri, mode: LaunchMode.externalApplication);
  } 
  // Jika geoUri gagal, coba luncurkan dengan webUri
  else if (await canLaunchUrl(webUri)) {
    await launchUrl(webUri, mode: LaunchMode.externalApplication); // Coba juga buka sebagai aplikasi eksternal
  } 
  // Jika keduanya gagal
  else {
    _showErrorSnackBar('Could not open map for this location.');
    // Sebagai alternatif, Anda bisa mencoba URL web yang lebih sederhana tanpa zoom,
    // atau hanya menampilkan pesan error.
    // Contoh fallback yang sangat sederhana jika semua gagal:
    // final Uri basicWebUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$$lat,$lon&q=$lat,$lon($');
    // if (await canLaunchUrl(basicWebUri)) {
    //   await launchUrl(basicWebUri);
    // } else {
    //   _showErrorSnackBar('Could not open any map service.');
    // }
  }
}

  void _showMapBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) { // Menggunakan bottomSheetContext
        // Warna sudah di-handle oleh _DetailScreenState
        // final themeProvider = Provider.of<ThemeProvider>(bottomSheetContext);
        // final isDark = themeProvider.isDarkMode;
        bool isCurrentlyDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;


        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Margin bawah agar tidak terlalu mepet
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isCurrentlyDark ? _background : Colors.white, // Menggunakan _background state
            borderRadius: const BorderRadius.all(Radius.circular(20)), // Rounded di semua sisi
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isCurrentlyDark ? Colors.white : Colors.black).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _accent, // Menggunakan _accent state
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Post Location',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCurrentlyDark ? _textLight : _textDark, // Menggunakan _textLight/_textDark state
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding( // Padding agar peta tidak mepet ke tepi
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(widget.latitude, widget.longitude),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('postLocation'),
                          position: LatLng(widget.latitude, widget.longitude),
                          infoWindow: InfoWindow(title: widget.description.isNotEmpty ? widget.description : 'Post Location'), // Deskripsi post sebagai info window
                        ),
                      },
                      mapType: MapType.normal,
                      zoomControlsEnabled: true,
                      myLocationEnabled: true, // Jika permission ada
                      myLocationButtonEnabled: true, // Jika permission ada
                      compassEnabled: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildGlassContainer( // Menggunakan _buildGlassContainer yang sudah ada
                  height: 60,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openMap, // Panggil _openMap yang sudah diperbarui
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map,
                              color: isCurrentlyDark ? _accent : _accent.withOpacity(0.8), // Menggunakan _accent state
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Open in Maps App', // Teks diubah agar lebih jelas
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: isCurrentlyDark ? _textLight : _textDark, // Menggunakan _textLight/_textDark state
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.open_in_new,
                              color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.5), // Menggunakan _textLight/_textDark state
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16), // Margin bawah di dalam bottom sheet
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // final themeProvider = Provider.of<ThemeProvider>(context); // Tidak perlu di sini jika _updateColors dipanggil dengan benar
    // final isDark = themeProvider.isDarkMode; // isDark bisa diambil dari state class

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        systemOverlayStyle: Provider.of<ThemeProvider>(context, listen: false).isDarkMode // listen false karena hanya untuk style awal
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        elevation: 0,
        backgroundColor: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? _background : _accent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? _textLight : Colors.white // Warna ikon kembali
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fullName,
              style: GoogleFonts.poppins(
                color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? _textLight : Colors.white, // Warna judul
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _timeAgo,
              style: GoogleFonts.poppins(
                color: (Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? _textLight : Colors.white).withOpacity(0.6), // Warna subjudul
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (isPostOwner)
            IconButton(
              icon: Icon(Icons.delete, color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? _textLight : Colors.white), // Warna ikon delete
              onPressed: _showDeleteConfirmation, // Panggil method yang sudah didefinisikan
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: widget.heroTag,
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black, // Background untuk gambar jika tidak memenuhi
                  image: DecorationImage(
                    // Tambahkan try-catch untuk base64Decode di sini untuk keamanan ekstra
                    image: MemoryImage(base64Decode(widget.imageBase64.startsWith('data:image') 
                                          ? widget.imageBase64.substring(widget.imageBase64.indexOf(',') + 1) 
                                          : widget.imageBase64)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Kode yang dimodifikasi:
Padding(
  // Ubah EdgeInsets.all(16) menjadi EdgeInsets.symmetric(vertical: 16.0)
  // Ini akan menghilangkan padding horizontal (kiri dan kanan) tetapi mempertahankan padding vertikal.
  // Atau, jika Anda ingin mengatur padding atas dan bawah secara spesifik:
  // padding: const EdgeInsets.only(top: 16.0, bottom: 16.0, left: 0, right: 0),
  padding: const EdgeInsets.symmetric(vertical: 16.0), 
  child: _buildGlassContainer(
    height: widget.description.length > 100 ? 200 : 150,
    // Anda mungkin juga ingin _buildGlassContainer memiliki width: double.infinity secara eksplisit
    // jika perilakunya tidak otomatis full-width, meskipun biasanya Container tanpa width akan mengisi parent.
    // Namun, karena _buildGlassContainer tidak memiliki parameter width, perubahan di Padding sudah cukup.
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16), // Padding internal ini tetap
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode 
                      ? _accent.withOpacity(0.2) 
                      : _accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.category,
              style: GoogleFonts.poppins(
                color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode 
                        ? _accent 
                        : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: GoogleFonts.poppins(
              fontSize: 16,
              height: 1.5,
              color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode 
                      ? _textLight 
                      : _textDark,
            ),
          ),
        ],
      ),
    ),
  ),
),
             // Bagian tombol Like & Comment dipindahkan ke dalam Padding agar konsisten
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  AnimatedLikeButton(
                    isLiked: isLiked,
                    isLoading: _isLiking,
                    likes: likes,
                    onTap: _toggleLike,
                    accentColor: _accent, // Teruskan warna aksen
                    isDarkMode: Provider.of<ThemeProvider>(context, listen: false).isDarkMode, showLikesList: () {  }, // Teruskan status dark mode
                  ),
                  const SizedBox(width: 16),
                  CommentButton(
                    commentCount: commentDetails.length,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent, // Sudah benar
                        builder: (context) => _buildCommentsSheet(),
                      );
                    },
                    accentColor: _accent, // Teruskan warna aksen
                    isDarkMode: Provider.of<ThemeProvider>(context, listen: false).isDarkMode, // Teruskan status dark mode
                  ),
                ],
              ),
            ),
            if (widget.latitude != 0 && widget.longitude != 0) // Cek lokasi valid
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Sesuaikan padding
                child: _buildGlassContainer(
                  height: 80, // Tinggi mungkin perlu disesuaikan
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showMapBottomSheet,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: _accent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'View Location',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? _textLight : _textDark,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: (Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? _textLight : _textDark).withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16), // Margin bawah akhir
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSheet() {
    // final themeProvider = Provider.of<ThemeProvider>(context); // Tidak perlu jika menggunakan state _background dkk.
    bool isCurrentlyDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    // Urutkan commentDetails berdasarkan timestamp terbaru di atas
    List<Map<String, dynamic>> sortedCommentDetails = List.from(commentDetails);
    sortedCommentDetails.sort((a, b) {
      Timestamp tsA = a['timestamp'] as Timestamp;
      Timestamp tsB = b['timestamp'] as Timestamp;
      return tsB.compareTo(tsA); // Terbaru di atas
    });


    return Padding( // Tambahkan Padding agar keyboard tidak menutupi TextField
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8), // Margin dikurangi agar lebih pas
        padding: const EdgeInsets.only(top:8), // Padding atas untuk handle
        decoration: BoxDecoration(
          color: isCurrentlyDark ? _background : Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
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
        child: DraggableScrollableSheet( // Bungkus dengan DraggableScrollableSheet
          initialChildSize: 0.6, // Ukuran awal saat muncul
          minChildSize: 0.3,   // Ukuran minimal saat ditarik ke bawah
          maxChildSize: 0.9,   // Ukuran maksimal saat ditarik ke atas
          expand: false, // Penting agar tidak memenuhi layar penuh secara default
          builder: (BuildContext _, ScrollController scrollController) {
            return Column(
              // mainAxisSize: MainAxisSize.min, // Tidak perlu lagi jika menggunakan DraggableScrollableSheet
              children: [
                Container( // Handle untuk drag
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: (isCurrentlyDark ? Colors.white : Colors.black).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Comments (${sortedCommentDetails.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCurrentlyDark ? _textLight : _textDark,
                        ),
                      ),
                      const Spacer(),
                      // Tombol sort bisa diimplementasikan jika diperlukan
                    ],
                  ),
                ),
                Expanded( // ListView.builder sekarang di dalam Expanded
                  child: sortedCommentDetails.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  'Be the first to comment',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController, // Gunakan scrollController dari DraggableScrollableSheet
                          // padding: EdgeInsets.zero, // Sudah di-handle oleh DraggableScrollableSheet
                          // shrinkWrap: true, // Tidak perlu dengan DraggableScrollableSheet dan Expanded
                          itemCount: sortedCommentDetails.length,
                          itemBuilder: (context, index) {
                            final comment = sortedCommentDetails[index];
                            final timeAgo = _formatTimeAgo(
                              (comment['timestamp'] as Timestamp).toDate(),
                            );

                            return Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar( // Avatar untuk komentator (bisa dikembangkan untuk menampilkan foto profil komentator)
                                    backgroundColor: isCurrentlyDark 
                                        ? Colors.white.withOpacity(0.1)
                                        : _accent.withOpacity(0.1),
                                    child: Text( // Inisial nama komentator
                                      (comment['userName'] as String?)?.isNotEmpty == true 
                                          ? (comment['userName'] as String)[0].toUpperCase() 
                                          : 'A',
                                      style: GoogleFonts.poppins(color: isCurrentlyDark ? _textLight : _accent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        comment['userName'] as String? ?? 'Anonymous',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: isCurrentlyDark ? _textLight : _textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeAgo,
                                        style: GoogleFonts.poppins(
                                          color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      comment['text'] as String? ?? '',
                                      style: GoogleFonts.poppins(
                                        color: isCurrentlyDark 
                                            ? _textLight.withOpacity(0.9)
                                            : _textDark.withOpacity(0.9),
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                                if (index < sortedCommentDetails.length - 1)
                                  Divider(
                                    indent: 72, // Sejajar dengan awal subtitle
                                    color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.1),
                                    height: 1,
                                  ),
                              ],
                            );
                          },
                        ),
                ),
                Padding( // TextField komentar di bawah
                  padding: const EdgeInsets.symmetric(horizontal:16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          maxLines: null, // Otomatis menyesuaikan tinggi
                          textCapitalization: TextCapitalization.sentences,
                          style: GoogleFonts.poppins(
                            color: isCurrentlyDark ? _textLight : _textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: GoogleFonts.poppins(
                              color: (isCurrentlyDark ? _textLight : _textDark).withOpacity(0.5),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isCurrentlyDark 
                                    ? Colors.white.withOpacity(0.1)
                                    : _accent.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isCurrentlyDark 
                                    ? Colors.white.withOpacity(0.1)
                                    : _accent.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: _accent),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10, // Sedikit dikurangi agar lebih pas
                            ),
                            fillColor: isCurrentlyDark 
                                ? Colors.white.withOpacity(0.05) // Lebih transparan untuk field
                                : _accent.withOpacity(0.05),
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _accent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          icon: _isCommenting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5, // Sedikit lebih tebal
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: _isCommenting ? null : _addComment,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}