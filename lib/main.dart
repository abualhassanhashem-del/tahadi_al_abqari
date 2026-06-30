import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String status = 'جاري التحقق من بيانات المستخدم...';
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _checkUserAndNavigate();
  }

  Future<void> _checkUserAndNavigate() async {
    try {
      // التحقق أولاً إذا كان اللاعب مسجلاً لاسم من قبل لتجنب التعطل
      final prefs = await SharedPreferences.getInstance();
      String? playerName = prefs.getString('playerName');

      // إذا لم يسجل اللاعب اسمه بعد، ننتقل مباشرة لشاشة الأقسام
      if (playerName == null || playerName.isEmpty) {
        setState(() => status = 'مرحباً بك في تحدي العباقرة!');
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CategoryScreen()),
          );
        }
        return;
      }

      setState(() => status = 'جاري الاتصال بـ Firebase...');
      
      // نجرب نقرأ من Firestore للتأكد من الاتصال
      await FirebaseFirestore.instance.collection('players').doc(playerName).get();
      
      setState(() => status = '✅ تم الاتصال بنجاح!');
      
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CategoryScreen()),
        );
      }
    } catch (e) {
      setState(() {
        status = '❌ خطأ في الاتصال بالسيرفر\nجاري الدخول بوضع عدم الاتصال...';
        hasError = true;
      });
      // ننتقل بعد ثانية في حالة وجود خطأ بالنت لكي لا يعلق التطبيق
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CategoryScreen()),
        );
      }
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
            ],
          ),
        ),
      ),
    );
  }
}
