import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';

class QuizScreen extends StatefulWidget {
  final String category;
  const QuizScreen({super.key, required this.category});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List questions = [];
  int currentQ = 0;

  int coins = 0;
  int gems = 0;
  int correctAnswers = 0;

  int timer = 30;
  Timer? _timer;

  bool showAnswer = false;
  bool _isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    await _loadQuestions();
    await _loadData();

    if (!mounted) return;

    if (questions.isNotEmpty) {
      _startTimer();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadQuestions() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      List allQ = [];

      String? cached = prefs.getString('cached_questions_${widget.category}');

      if (cached != null && cached.isNotEmpty) {
        allQ = json.decode(cached);
      } else {
        // حماية: استخدام DefaultAssetBundle للوصول الآمن لملفات assets
        final manifestContent = await DefaultAssetBundle.of(context)
            .loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        
        // التحقق من وجود الملف قبل تحميله لتجنب الكرش
        if (!manifestMap.containsKey('assets/questions.json')) {
          setState(() => hasError = true);
          return;
        }

        final data = await DefaultAssetBundle.of(context)
            .loadString("assets/questions.json");

        List assetQ = json.decode(data);

        if (widget.category == 'عامة') {
          allQ = assetQ;
        } else {
          allQ = assetQ
              .where((q) => q['type'] == widget.category)
              .toList();
        }

        await prefs.setString(
          'cached_questions_${widget.category}',
          json.encode(allQ),
        );
      }

      if (!mounted) return;

      setState(() {
        // التأكد من خلط الأسئلة بأمان
        if (allQ.isNotEmpty) {
          questions = List.from(allQ)..shuffle();
        } else {
          questions = [];
        }
      });
    } catch (e) {
      debugPrint('خطأ في تحميل الأسئلة: $e');
      if (!mounted) return;
      setState(() {
        questions = [];
        hasError = true;
      });
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      coins = prefs.getInt('coins') ?? 0;
      gems = prefs.getInt('gems') ?? 0;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    timer = 30;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (timer > 0) {
        setState(() => timer--);
      } else {
        _nextQuestion();
      }
    });
  }

  void _checkAnswer(int index) {
    if (showAnswer) return;

    _timer?.cancel();

    // حماية إضافية للتحقق من وجود الأسئلة ومفتاح الإجابة الصحيحة
    if (questions.isEmpty || currentQ >= questions.length) return;

    final q = questions[currentQ];
    bool correct = index == q['correct'];

    if (correct) {
      setState(() {
        coins += 10;
        correctAnswers++;
      });
      _saveCoins();
      _syncCoins();
    }

    setState(() => showAnswer = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (!mounted) return;

    if (currentQ < questions.length - 1) {
      setState(() {
        currentQ++;
        showAnswer = false;
      });

      _startTimer();
    } else {
      _endQuiz();
    }
  }

  Future<void> _syncCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('playerName');
      if (name == null || name.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('players')
          .doc(name)
          .set({'coins': coins}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('فشل المزامنة: $e');
    }
  }

  Future<void> _saveCoins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
  }

  void _endQuiz() {
    _timer?.cancel();

    if (!mounted) return;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('انتهت اللعبة'),
        content: Text(
            'الإجابات الصحيحة: $correctAnswers / ${questions.length}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق الـ Dialog
              Navigator.pop(context); // الرجوع لشاشة الأقسام
            },
            child: const Text('خروج'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError || questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category)),
        body: const Center(
          child: Text(
            'لا توجد أسئلة لهذا القسم أو حدث خطأ في التحميل', 
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final q = questions[currentQ];
    // حماية للتأكد من وجود مصفوفة الإجابات
    final List answers = (q['a'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: Column(
        children: [
          Text("⏱ $timer | 💰 $coins | 💎 $gems", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                q['q'] ?? 'سؤال بدون نص',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: answers.length,
              itemBuilder: (context, i) {
                final correct = i == (q['correct'] ?? -1);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton(
                    onPressed: showAnswer ? null : () => _checkAnswer(i),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: showAnswer
                          ? (correct ? Colors.green : Colors.red)
                          : Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(
                      answers[i].toString(),
                      style: TextStyle(
                        fontSize: 16,
                        color: showAnswer ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
