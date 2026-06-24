import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'store_screen.dart';
import 'wheel_screen.dart';
import 'leaderboard_screen.dart';
import 'quiz_screen.dart';
import 'image_quiz_screen.dart';
import 'add_question_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String playerName = 'لاعب';
  String playerTitle = 'العبقري المبتدأ';
  int coins = 0;
  int gems = 0;
  int avatar = 0;
  bool isDark = false;
  String? playerId;
  List<String> ownedTitles = ['العبقري المبتدأ'];

  // أيقونات الصور الرمزية
  final List<IconData> avatarIcons = [
    Icons.boy, Icons.person, Icons.woman, Icons.man, Icons.person_4, Icons.girl
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    playerId = prefs.getString('playerId');

    bool firstTime = prefs.getBool('firstTime')?? true;

    setState(() {
      playerName = prefs.getString('playerName')?? 'لاعب';
      playerTitle = prefs.getString('title')?? 'العبقري المبتدأ';
      coins = prefs.getInt('coins')?? 0;
      avatar = prefs.getInt('playerAvatar')?? 0;
      gems = prefs.getInt('gems')?? 0;
      isDark = prefs.getBool('isDark')?? false;
      ownedTitles = prefs.getStringList('ownedTitles')?? ['العبقري المبتدأ'];
    });

    if (firstTime && playerId!= null) {
      coins += 200;
      await prefs.setInt('coins', coins);
      await prefs.setBool('firstTime', false);

      await FirebaseFirestore.instance.collection('players').doc(playerId).set({
        'name': playerName,
        'coins': coins,
        'gems': gems,
        'title': playerTitle,
        'avatar': avatar,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) _showBonusDialog();
    }

    if (playerId!= null) {
      final doc = await FirebaseFirestore.instance.collection('players').doc(playerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          coins = data['coins']?? coins;
          gems = data['gems']?? gems;
          playerTitle = data['title']?? playerTitle;
        });
        await prefs.setInt('coins', coins);
        await prefs.setInt('gems', gems);
      }
    }
  }

  void _showBonusDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 مبروك'),
        content: const Text('ربحت 200 عملة مجانية ترحيباً بك في تحدي العباقرة!'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('روعة'))],
      ),
    );
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isDark =!isDark);
    await prefs.setBool('isDark', isDark);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // التحقق من اللقب قبل فتح "ضع سؤالك"
  void _checkTitleAndOpenAddQuestion() {
    // إذا عنده أكثر من لقبين أو عنده لقب غير المجاني
    if (ownedTitles.length > 2 ||!ownedTitles.contains('العبقري المبتدأ')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AddQuestionScreen()));
    } else {
      _showSnack('يجب شراء لقب من المتجر أولاً');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                          : [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _toggleTheme),
                        const SizedBox(width: 10),
                        IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () {
                          _showSnack('الإشعارات قريباً');
                        }),
                      ]),
                      Row(children: [
                        _buildCurrency(Icons.monetization_on, coins, Colors.amber),
                        const SizedBox(width: 15),
                        _buildCurrency(Icons.diamond, gems, Colors.cyan),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const Text('تحدي العباقرة',
                    style: TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.bold)),
                const Text('العب، تحدّى، اكسب',
                    style: TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 20),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(avatarIcons[avatar], size: 40, color: Color(0xFF6A11CB))
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(playerTitle, style: const TextStyle(color: Colors.amber, fontSize: 14)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.person, color: Colors.white),
                        onPressed: () => _showSnack('صفحة اللاعب قريباً'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // الأزرار الرئيسية الثلاثة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCircleButton('المتجر', Icons.store, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen()));
                    }),
                    _buildCircleButton('دولاب الحظ', Icons.casino, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WheelScreen()));
                    }),
                    _buildCircleButton('الصدارة', Icons.leaderboard, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen()));
                    }),
                  ],
                ),
                const SizedBox(height: 25),

                // أزرار المسابقات - تتحرك أفقي يمين/يسار
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('اختر المسابقة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                Container(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCategoryBtn('عامة', Icons.public, 'عامة'),
                      _buildCategoryBtn('تاريخ', Icons.history_edu, 'تاريخ'),
                      _buildCategoryBtn('حزورة', Icons.psychology, 'حزورة'),
                      _buildCategoryBtn('جغرافيا', Icons.map, 'جغرافيا'),
                      _buildCategoryBtn('رياضة', Icons.sports_soccer, 'رياضة'),
                      _buildCategoryBtn('مدن', Icons.location_city, 'مدن'),
                      _buildCategoryBtn('صورية', Icons.image, 'صورية'),
                      _buildCategoryBtn('ضع سؤالك', Icons.add_circle, 'add_question'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrency(IconData icon, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 5),
        Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildCircleButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 35),
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  // زر المسابقة الدائري - الكتابة بالوسط مرتبة
  Widget _buildCategoryBtn(String label, IconData icon, String category) {
    return Padding(
      padding: EdgeInsets.only(left: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (category == 'add_question') {
                _checkTitleAndOpenAddQuestion();
              } else if (category == 'صورية') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ImageQuizScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(category: category)));
              }
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}