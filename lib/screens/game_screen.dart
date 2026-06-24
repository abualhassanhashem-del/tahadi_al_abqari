import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List questions = [];
  int current = 0;
  int score = 0;
  int coins = 0;
  String playerId = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    playerId = p.getString('playerId')?? '';
    coins = p.getInt('coins')?? 0;

    final data = await rootBundle.loadString('assets/questions.json');
    final all = json.decode(data) as List;
    all.shuffle(Random());
    questions = all.take(10).toList(); // 10 أسئلة كل جولة

    setState(() => loading = false);
  }

  void _answer(int index) async {
    final q = questions[current];
    bool correct = index == q['correct'];

    if (correct) {
      score++;
      coins += 10;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ صحيح! +10 عملات'), backgroundColor: Colors.green, duration: Duration(milliseconds: 800)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ! الصحيح: ${q['a'][q['correct']]}'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
      );
    }

    await Future.delayed(const Duration(milliseconds: 900));

    if (current < questions.length - 1) {
      setState(() => current++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('coins', coins);

    if (playerId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('players').doc(playerId).set({
        'coins': coins,
        'lastScore': score,
        'lastPlayed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text('انتهت الجولة!'),
      content: Text('نتيجتك: $score / ${questions.length}\nربحت: ${score * 10} عملة'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('العودة'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final q = questions[current];
    return Scaffold(
      appBar: AppBar(
        title: Text('سؤال ${current + 1}/${questions.length}'),
        backgroundColor: const Color(0xFF6A11CB),
        actions: [Center(child: Padding(padding: const EdgeInsets.only(left: 16), child: Text('$coins 💰', style: const TextStyle(fontSize: 18))))],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(value: (current + 1) / questions.length, backgroundColor: Colors.white24, color: Colors.amber),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text(q['q'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Text('${q['type']} • ${q['diff']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 30),
         ...List.generate(4, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              onPressed: () => _answer(i),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(q['a'][i], style: const TextStyle(fontSize: 18)),
            ),
          )),
        ]),
      ),
    );
  }
}