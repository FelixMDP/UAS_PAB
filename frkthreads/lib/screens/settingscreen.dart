import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart'; // Pastikan path ini benar

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Tentukan warna berdasarkan tema untuk konsistensi
    final currentBackgroundColor = isDark ? const Color(0xFF293133) : const Color(0xFFF1E9D2);
    final currentAppBarColor = isDark ? Colors.grey[900] : const Color(0xFFB88C66);
    final currentTextColor = isDark ? Colors.white : const Color(0xFF293133);
    final currentIconColor = isDark ? Colors.white70 : Colors.black87;
    final currentListTileTextColor = isDark ? Colors.white : Colors.black87;


    return Scaffold(
      backgroundColor: currentBackgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: currentTextColor)),
        backgroundColor: currentAppBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: currentTextColor),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.color_lens, color: currentIconColor),
            title: Text('Dark Mode', style: TextStyle(color: currentListTileTextColor)),
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeColor: isDark ? Colors.blue[700] : const Color(0xFF2D3B3A),
              inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[300],
              inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
          const Divider(), // Pemisah antar item
          ListTile(
            leading: Icon(Icons.logout, color: currentIconColor),
            title: Text('Logout', style: TextStyle(color: currentListTileTextColor)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              // Pastikan Anda memiliki route bernama '/signin' atau ganti dengan halaman login yang sesuai
              // Menggunakan pushNamedAndRemoveUntil untuk membersihkan stack navigasi
              Navigator.of(context).pushNamedAndRemoveUntil('/signin', (Route<dynamic> route) => false);
            },
          ),
          // Tambahkan opsi pengaturan lainnya di sini jika perlu
        ],
      ),
    );
  }
}