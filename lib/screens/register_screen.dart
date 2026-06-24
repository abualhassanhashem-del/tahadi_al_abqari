import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  int selectedAvatar = 0;

  final List<Map<String, dynamic>> avatars = [
    {'icon': Icons.boy, 'name': 'ولد'},
    {'icon': Icons.person, 'name': 'شاب'},
    {'icon': Icons.woman, 'name': 'امرأة'},
    {'icon': Icons.man, 'name': 'رجل'},
    {'icon': Icons.person_4, 'name': 'رجل متوسط'},
    {'icon': Icons.girl, 'name': 'بنت'},
  ];

  @override
  void initState() {
    super.initState();
    _checkIfRegistered();
  }

  void _checkIfRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    bool isRegistered = prefs.getBool('isRegistered')?? false;
    if (isRegistered) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    }
  }

  void _saveAndEnter() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اكتب اسمك المستعار أولاً')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    // 1. حفظ محلي
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', name);
    await prefs.setString('playerPhone', phone);
    await prefs.setInt('playerAvatar', selectedAvatar);
    await prefs.setString('title', 'العبقري المبتدأ');
    await prefs.setInt('coins', 200);
    await prefs.setInt('gems', 0);
    await prefs.setInt('level', 1);
    await prefs.setBool('isRegistered', true);
    await prefs.setStringList('ownedTitles', ['العبقري المبتدأ']);

    // 2. حفظ في Firebase - هذا الجديد
    try {
      await FirebaseFirestore.instance.collection('players').doc(phone.isNotEmpty? phone : name).set({
        'name': name,
        'phone': phone,
        'avatar': selectedAvatar,
        'title': 'العبقري المبتدأ',
        'coins': 200,
        'gems': 0,
        'level': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('خطأ Firebase: $e');
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Text(
                  'تحدي العباقرة',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  'العب، تحدّى، اكسب',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                SizedBox(height: 40),

                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'اكتب اسمك المستعار',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 15),

                // حقل الهاتف الجديد
                TextField(
                  controller: _phoneController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'رقم الهاتف (اختياري)',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 30),

                Text('اختر شخصيتك', style: TextStyle(color: Colors.white, fontSize: 18)),
                SizedBox(height: 15),
                Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  alignment: WrapAlignment.center,
                  children: List.generate(avatars.length, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => selectedAvatar = index),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: selectedAvatar == index? Colors.amber : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selectedAvatar == index? Colors.amber : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(avatars[index]['icon'], size: 40, color: selectedAvatar == index? Colors.black : Colors.white),
                            SizedBox(height: 5),
                            Text(avatars[index]['name'], style: TextStyle(fontSize: 12, color: selectedAvatar == index? Colors.black : Colors.white)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 30),

                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ميزة المعرض قريباً')),
                    );
                  },
                  icon: Icon(Icons.photo_library, color: Colors.white),
                  label: Text('اختر صورة من المعرض', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _saveAndEnter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: EdgeInsets.symmetric(horizontal: 80, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text('دخول', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                SizedBox(height: 15),
                Text('🎁 هدية تسجيل: 200 عملة مجاناً', style: TextStyle(color: Colors.amber, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}