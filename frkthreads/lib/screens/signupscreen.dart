import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frkthreads/screens/homescreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Custom color palette - Consistent with SignInScreen
  static const Color _background = Color(0xFF293133);
  static const Color _cream = Color(0xFFF1E9D2);
  static const Color _textDark = Color(0xFF293133);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Sign Up', style: TextStyle(color: _cream)),
        backgroundColor: _background,
        foregroundColor: _cream,
        elevation: 0,
        centerTitle: true, // Center the title
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center content vertically
                children: [
                  const SizedBox(height: 32.0),
                  Text(
                    'Create an Account', // Added a title
                    style: TextStyle(
                      color: _cream,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32.0),
                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    textColor: _textDark,
                    fieldColor: _cream,
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter your full name'
                                : null,
                  ),
                  const SizedBox(height: 16.0),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    textColor: _textDark,
                    fieldColor: _cream,
                    validator:
                        (value) =>
                            value == null ||
                                    value.isEmpty ||
                                    !_isValidEmail(value)
                                ? 'Please enter a valid email'
                                : null,
                  ),
                  const SizedBox(height: 16.0),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    obscureText: !_isPasswordVisible,
                    textColor: _textDark,
                    fieldColor: _cream,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: _textDark,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    obscureText: !_isConfirmPasswordVisible,
                    textColor: _textDark,
                    fieldColor: _cream,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: _textDark,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24.0),
                  _isLoading
                      ? const CircularProgressIndicator(color: _cream)
                      : SizedBox(
                        width: double.infinity, // Make button full width
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cream,
                            foregroundColor: _textDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _signUp,
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    Color? textColor,
    Color? fieldColor,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: textColor ?? Colors.black),
      cursorColor: textColor,
      decoration: InputDecoration(
        filled: true,
        fillColor: fieldColor ?? Colors.white,
        labelText: label,
        labelStyle: TextStyle(color: textColor ?? Colors.black),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        prefixIcon: Icon(icon, color: textColor ?? Colors.black),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: textColor ?? Colors.black),
        ),
      ),
      validator: validator,
    );
  }

  void _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim(); // Ambil fullName

    setState(() => _isLoading = true);

    try {
      // 1. Buat pengguna dengan email dan password
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2. Setelah pengguna berhasil dibuat, update displayName mereka
      if (userCredential.user != null) {
        // Pastikan user tidak null
        await userCredential.user!.updateDisplayName(
          fullName,
        ); // <-- TAMBAHKAN BARIS INI
        print(
          'Display name updated to: $fullName',
        ); // Opsional: untuk debugging
      }

      // 3. Simpan informasi tambahan pengguna ke Firestore (ini sudah Anda lakukan)
      //    Penting: Pastikan userCredential.user!.uid tersedia
      if (userCredential.user != null) {
        // Cek lagi untuk Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'fullName': fullName,
              'email': email,
              'createdAt': Timestamp.now(),
              'uid': userCredential.user!.uid,
              'followers': [], // Initialize empty followers array
              'following': [], // Initialize empty following array
              'bio': '', // Initialize empty bio for edit profile
            });
      }

      if (!mounted) return;
      // Navigasi ke HomeScreen setelah semua selesai
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      _showErrorMessage(_getAuthErrorMessage(error.code));
    } catch (error) {
      _showErrorMessage('An error occurred during sign up: $error');
    } finally {
      if (mounted) {
        // Pastikan widget masih mounted sebelum setState
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String email) {
    String emailRegex =
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$";
    return RegExp(emailRegex).hasMatch(email);
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
