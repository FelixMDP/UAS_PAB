import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frkthreads/screens/homescreen.dart';     // Ganti dengan path ke HomeScreen Anda
import 'package:frkthreads/screens/signinscreen.dart';   // Ganti dengan path ke LoginScreen Anda

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(), 
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Something went wrong! Please restart the app.'),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          
          return const HomeScreen(); 
        }

        return const SignInScreen();
      },
    );
  }
}