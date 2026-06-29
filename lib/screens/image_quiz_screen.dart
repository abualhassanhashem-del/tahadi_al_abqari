import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';

class ImageQuizScreen extends StatefulWidget {
  const ImageQuizScreen({super.key});

  @override
  State<ImageQuizScreen> createState() => _ImageQuizScreenState();
}

class _ImageQuizScreenState extends State<ImageQuizScreen> {
  List questions = [];
  int currentQ = 0;

  int coins = 0;
  int gems = 0;
  int correctAnswers = 0;

  int timer = 30;
  Timer? _timer;

  List<String> userAnswer = [];
  List<String> availableLetters = [];
  List<bool> usedLetters = [];

  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    await _loadQuestions();
    await _loadData();

    if (mounted && questions.isNotEmpty) {
      _setupQuestion();
      _startTimer();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadQuestions() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      String? cached = prefs.getString('cached_image_questions');

      if (cached != null) {
        questions = json.decode(cached);
      } else {
        String data = await DefaultAssetBundle.of(context)
            .loadString("assets/image_questions.json");

        questions = json.decode(data);
        await prefs.setString('cached_image_questions', data);
      }
    } catch (e) {
      questions = [];
    }

    questions.shuffle();
  }

  Future<void> _updateQuestions() async {
    if (coins < 50) {
      _showSnack('تحتاج 50 💰');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('approved_image_questions')
          .limit(30)
          .get();

      if (snapshot.docs.isEmpty) {
        _showSnack('لا توجد تحديثات الآن');
        setState(() => _isUpdating = false);
        return;
      }

      List newQ = snapshot.docs.map((d) {
        var data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      coins -= 50;
      await _saveCoins();

      questions = newQ;
      currentQ = 0;

      _setupQuestion();
      _startTimer();

      _showSnack('تم التحديث');

    } catch (e) {
      // 🔥 مهم جداً: التطبيق لا ينهار لو Firebase فشل
      _showSnack('لا يوجد اتصال - العمل أوفلاين');
    }

    if (mounted) {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    coins = prefs.getInt('coins') ?? 0;
    gems = prefs.getInt('gems') ?? 0;

    if (mounted) setState(() {});
  }

  void _setupQuestion() {
    if (questions.isEmpty || currentQ >= questions.length) return;

    final q = questions[currentQ];
    final answer = (q['answer'] ?? '').toString();

    if (answer.isEmpty) return;

    List<String> letters = answer.split('');

    List<String> extra = [
      'ا','ب','ت','ث','ج','ح','خ','د','ر','ز','س','ش','ص','ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','ه','و','ي'
    ];

    extra.shuffle();

    letters.addAll(extra.take(6));
    letters.shuffle();

    setState(() {
      availableLetters = letters;
      userAnswer = List.filled(answer.length, '');
      usedLetters = List.filled(letters.length, false);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    timer = 30;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (timer <= 0) {
        _nextQuestion(false);
      } else {
        setState(() => timer--);
      }
    });
  }

  void _addLetter(int index) {
    if (index >= availableLetters.length) return;
    if (usedLetters[index]) return;

    for (int i = 0; i < userAnswer.length; i++) {
      if (userAnswer[i].isEmpty) {
        setState(() {
          userAnswer[i] = availableLetters[index];
          usedLetters[index] = true;
        });
        break;
      }
    }

    _checkAnswer();
  }

  void _checkAnswer() {
    if (userAnswer.contains('')) return;

    _timer?.cancel();

    final correct = questions[currentQ]['answer'] ?? '';
    final answer = userAnswer.join();

    bool ok = answer == correct;

    if (ok) {
      coins += 15;
      correctAnswers++;
      _saveCoins();
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _nextQuestion(ok);
    });
  }

  void _nextQuestion(bool ok) {
    if (!mounted) return;

    if (currentQ < questions.length - 1) {
      setState(() => currentQ++);
      _setupQuestion();
      _startTimer();
    } else {
      _endQuiz();
    }
  }

  Future<void> _saveCoins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
  }

  void _endQuiz() {
    _timer?.cancel();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('انتهى'),
        content: Text('صح: $correctAnswers / ${questions.length}'),
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
      appBar: AppBar(title: const Text('تحدي الصور')),
      body: Column(
        children: [
          Text('⏱ $timer   💰 $coins'),

          const SizedBox(height: 10),

          Text(q['hint'] ?? ''),

          const SizedBox(height: 10),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: List.generate(4, (i) {
                final images = q['images'] ?? [];
                return Container(
                  margin: const EdgeInsets.all(6),
                  color: Colors.grey[300],
                  child: Center(
                    child: Text(
                      (i < images.length) ? images[i].toString() : '❓',
                    ),
                  ),
                );
              }),
            ),
          ),

          Wrap(
            children: List.generate(userAnswer.length, (i) {
              return Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(10),
                color: Colors.amber,
                child: Text(userAnswer[i]),
              );
            }),
          ),

          Wrap(
            children: List.generate(availableLetters.length, (i) {
              return GestureDetector(
                onTap: () => _addLetter(i),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(10),
                  color: usedLetters[i] ? Colors.grey : Colors.orange,
                  child: Text(availableLetters[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
