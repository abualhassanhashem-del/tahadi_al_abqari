import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/category_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
  String status = 'جاري الاتصال بـ Firebase...';
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _checkFirebaseAndNavigate();
  }

  Future<void> _checkFirebaseAndNavigate() async {
    try {
      // نجرب نقرأ من Firestore
      await FirebaseFirestore.instance.collection('players').limit(1).get();
      
      setState(() => status = '✅ تم الاتصال بنجاح!');
      
      // ننتظر ثانية ونص عشان المستخدم يشوف الرسالة
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted) {
        // ندخل اللعبة
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CategoryScreen()),
        );
      }
    } catch (e) {
      setState(() {
        status = '❌ خطأ في الاتصال\nتأكد من google-services.json';
        hasError = true;
      });
    }
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
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 40),
              if (!hasError) const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      status = 'جاري إعادة المحاولة...';
                      hasError = false;
                    });
                    _checkFirebaseAndNavigate();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}