import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Tambahkan jika belum ada, untuk konsistensi font

class AnimatedLikeButton extends StatelessWidget {
  final bool isLiked;
  final bool isLoading;
  final int likes;
  final VoidCallback onTap;
  final VoidCallback? onLongPress; // Tetap opsional
  final VoidCallback? showLikesList; // Jadikan opsional jika tidak selalu digunakan
  final Color accentColor;         // Parameter baru
  final bool isDarkMode;          // Parameter baru

  const AnimatedLikeButton({
    Key? key,
    required this.isLiked,
    required this.isLoading,
    required this.likes,
    required this.onTap,
    this.onLongPress,
    this.showLikesList,      // Tambahkan ke constructor
    required this.accentColor, // Tambahkan ke constructor
    required this.isDarkMode,   // Tambahkan ke constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tentukan warna berdasarkan isDarkMode dan accentColor
    final Color iconColor = isLiked
        ? Colors.red // Warna merah untuk like
        : (isDarkMode ? Colors.white70 : accentColor.withOpacity(0.8));
    final Color textColor = isLiked
        ? Colors.red
        : (isDarkMode ? Colors.white70 : accentColor.withOpacity(0.9));
    final Color containerColor = isLiked && !isDarkMode // Hanya di light mode jika di-like
        ? accentColor.withOpacity(0.1) // Background lembut saat di-like di light mode
        : Colors.transparent;


    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        onLongPress: onLongPress, // Anda bisa memanggil showLikesList di sini jika mau
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: containerColor, // Gunakan warna container yang sudah ditentukan
            borderRadius: BorderRadius.circular(20),
            border: Border.all( // Tambahkan border tipis agar terlihat di dark mode jika tidak di-like
              color: isDarkMode && !isLiked ? Colors.white.withOpacity(0.2) : Colors.transparent,
              width: 0.5,
            )
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hilangkan AnimatedScale jika tidak terlalu signifikan atau menyebabkan jank
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_outline,
                color: iconColor, // Gunakan iconColor
                size: 22, // Sedikit disesuaikan ukurannya
              ),
              const SizedBox(width: 6), // Jarak sedikit lebih besar
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('loader'),
                        width: 16, // Ukuran loader disesuaikan
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      )
                    : Text(
                        '$likes',
                        key: ValueKey<int>(likes), // Key untuk animasi yang benar
                        style: GoogleFonts.poppins( // Konsistensi font
                          color: textColor, // Gunakan textColor
                          fontWeight: FontWeight.w600, // Sedikit lebih tebal
                          fontSize: 14,
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

class CommentButton extends StatelessWidget {
  final int commentCount;
  final VoidCallback onTap;
  final Color accentColor; // Parameter baru
  final bool isDarkMode;   // Parameter baru

  const CommentButton({
    Key? key,
    required this.commentCount,
    required this.onTap,
    required this.accentColor, // Tambahkan di constructor
    required this.isDarkMode,   // Tambahkan di constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tentukan warna berdasarkan isDarkMode dan accentColor
    final Color iconColor = isDarkMode ? Colors.white70 : accentColor.withOpacity(0.8);
    final Color textColor = isDarkMode ? Colors.white70 : accentColor.withOpacity(0.9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20), // Samakan dengan LikeButton
        child: Container( // Gunakan Container untuk border jika perlu
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
           decoration: BoxDecoration(
            color: Colors.transparent, // Tidak ada background khusus by default
            borderRadius: BorderRadius.circular(20),
            border: Border.all( // Tambahkan border tipis agar terlihat di dark mode
              color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.transparent,
              width: 0.5,
            )
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: iconColor, // Gunakan iconColor
                size: 22, // Samakan dengan LikeButton
              ),
              const SizedBox(width: 6), // Samakan dengan LikeButton
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Text(
                  '$commentCount',
                  key: ValueKey<int>(commentCount),
                  style: GoogleFonts.poppins( // Konsistensi font
                    color: textColor, // Gunakan textColor
                    fontWeight: FontWeight.w600, // Samakan dengan LikeButton
                    fontSize: 14,
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