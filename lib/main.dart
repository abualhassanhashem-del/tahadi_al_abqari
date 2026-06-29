import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/category_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase اختياري (لا يوقف التطبيق إذا فشل)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase not available: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحدي العباقرة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Cairo',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String status = 'تشغيل اللعبة...';
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkFirebase();
  }

  Future<void> _checkFirebase() async {
    try {
      await FirebaseFirestore.instance
          .collection('players')
          .limit(1)
          .get();

      isOnline = true;
      status = 'تم الاتصال بالخادم';
    } catch (e) {
      isOnline = false;
      status = 'وضع أوفلاين';
    }

    if (!mounted) return;

    setState(() {});

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CategoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'تحدي العباقرة',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                status,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
