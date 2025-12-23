import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'auth_page.dart';
import 'registration_page.dart';
import 'home_screen.dart';
import 'admin_home_page.dart';
import 'prize_upload_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase Registration',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthPage(),
        '/register': (context) => RegistrationPage(),
        '/home': (context) => HomeScreen(),
        '/admin-home': (context) => AdminHomePage(),
        '/prize-upload': (context) => PrizeUploadPage(),
        // Add other pages here as you create them
      },
    );
  }
}

// ...existing code...
