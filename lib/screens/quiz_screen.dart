import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

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
  bool _isUpdating = false;

  List<int> disabledAnswers = [];

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

      String? cached =
          prefs.getString('cached_questions_${widget.category}');

      if (cached != null && cached.isNotEmpty) {
        allQ = json.decode(cached);
      } else {
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
        questions = allQ..shuffle();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => questions = []);
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
        _nextQuestion(false);
      }
    });
  }

  void _checkAnswer(int index) {
    if (showAnswer) return;

    _timer?.cancel();

    final q = questions[currentQ];
    bool correct = index == q['correct'];

    if (correct) {
      coins += 10;
      correctAnswers++;
      _saveCoins();
      _syncCoins();
    }

    setState(() => showAnswer = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion(correct);
    });
  }

  void _nextQuestion(bool ok) {
    if (!mounted) return;

    if (currentQ < questions.length - 1) {
      setState(() {
        currentQ++;
        showAnswer = false;
        disabledAnswers.clear();
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
      if (name == null) return;

      await FirebaseFirestore.instance
          .collection('players')
          .doc(name)
          .set({'coins': coins}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _saveCoins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
  }

  void _endQuiz() {
    _timer?.cancel();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('انتهت اللعبة'),
        content: Text(
            'الإجابات الصحيحة: $correctAnswers / ${questions.length}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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

    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('لا توجد أسئلة')),
      );
    }

    final q = questions[currentQ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: Column(
        children: [
          Text("⏱ $timer | 💰 $coins | 💎 $gems"),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                q['q'] ?? '',
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: 4,
              itemBuilder: (context, i) {
                final correct = i == q['correct'];

                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: ElevatedButton(
                    onPressed: showAnswer ? null : () => _checkAnswer(i),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: showAnswer
                          ? (correct ? Colors.green : Colors.red)
                          : Colors.white,
                    ),
                    child: Text(q['a'][i]),
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
