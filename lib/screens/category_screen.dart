import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'quiz_screen.dart';
import 'image_quiz_screen.dart';
import 'wheel_screen.dart';
import 'add_question_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  int coins = 0;
  int gems = 0;
  int level = 1;
  bool isOnline = true;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkConnection();
    _listenToConnection();
  }

  // 1. يتحقق من النت بأمان
  Future<void> _checkConnection() async {
    var result = await Connectivity().checkConnectivity();
    bool online = result != ConnectivityResult.none;
    setState(() => isOnline = online);
    
    if (online) {
      await Future.delayed(const Duration(milliseconds: 500));
      _syncDataToFirebase();
    }
  }

  // 2. يستمع لتغير النت - يزامن تلقائي
  void _listenToConnection() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      bool wasOffline = !isOnline;
      setState(() => isOnline = result != ConnectivityResult.none);
      
      if (wasOffline && isOnline) {
        _syncDataToFirebase();
      }
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      coins = prefs.getInt('coins') ?? 0;
      gems = prefs.getInt('gems') ?? 0;
      level = prefs.getInt('level') ?? 1;
    });
  }

  // 3. يزامن العملات للفايربيس بأمان (مع حماية لاسم اللاعب)
  Future<void> _syncDataToFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? playerName = prefs.getString('playerName');
      
      // ❌ حماية مهمة: إذا لم يسجل اللاعب اسمه بعد، لا تحاول المزامنة لتجنب الكرش
      if (playerName == null || playerName.isEmpty) {
        print('لم يتم العثور على اسم لاعب، تم إلغاء المزامنة مؤقتاً');
        return;
      }

      await FirebaseFirestore.instance.collection('players').doc(playerName).set({
        'coins': coins,
        'gems': gems,
        'level': level,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('مزامنة فشلت: $e');
    }
  }

  void _openCategory(String category) {
    if (category == 'صورية') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageQuizScreen())).then((_) => _loadData());
    } else if (category == 'ضع سؤالك') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddQuestionScreen())).then((_) => _loadData());
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(category: category))).then((_) => _loadData());
    }
  }

  void _openWheel() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WheelScreen())).then((_) => _loadData());
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
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
        child: SafeArea(
          child: Column(
            children: [
              // الشريط العلوي - يبقى ظاهر دائماً
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('مرحلة $level', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            if (!isOnline) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.wifi_off, color: Colors.white54, size: 16),
                            ],
                          ],
                        ),
                        const Text('تحدي المعلومات', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    Row(
                      children: [
                        _buildCurrency(Icons.diamond, gems, const Color(0xFF00E5FF)),
                        const SizedBox(width: 12),
                        _buildCurrency(Icons.monetization_on, coins, const Color(0xFFFFD700)),
                      ],
                    ),
                  ],
                ),
              ),

              // دولاب الحظ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _openWheel,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.casino, color: Colors.amber, size: 32),
                        SizedBox(width: 12),
                        Text('دولاب الحظ - دورة مجانية كل يوم', 
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text('اختر القسم', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // الأقسام
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildCategory('عامة', Icons.public, Colors.blue),
                    _buildCategory('تاريخ', Icons.history_edu, Colors.brown),
                    _buildCategory('حزورة', Icons.psychology, Colors.purple),
                    _buildCategory('جغرافيا', Icons.public, Colors.green),
                    _buildCategory('رياضة', Icons.sports_soccer, Colors.orange),
                    _buildCategory('مدن', Icons.location_city, Colors.teal),
                    _buildCategory('صورية', Icons.image, Colors.pink),
                    _buildCategory('ضع سؤالك', Icons.add_circle, Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrency(IconData icon, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _openCategory(title),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
