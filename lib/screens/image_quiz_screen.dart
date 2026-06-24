import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

class ImageQuizScreen extends StatefulWidget {
  const ImageQuizScreen({super.key});

  @override
  State<ImageQuizScreen> createState() => _ImageQuizScreenState();
}

class _ImageQuizScreenState extends State<ImageQuizScreen> {
  List questions = [];
  List<String> cachedQuestionIds = [];
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
    if (questions.isNotEmpty && mounted) {
      _setupQuestion();
      _startTimer();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_image_questions');
    List allQ = [];

    if (cachedData!= null) {
      allQ = json.decode(cachedData);
      cachedQuestionIds = allQ.map((q) => q['id'].toString()).toList();
    } else {
      try {
        String data = await DefaultAssetBundle.of(context).loadString("assets/image_questions.json");
        allQ = json.decode(data);
        await _saveToCache(allQ);
      } catch (e) {
        print('خطأ في تحميل الأسئلة الصورية');
      }
    }

    if (mounted) {
      setState(() {
        questions = allQ;
        questions.shuffle();
      });
    }
  }

  Future<void> _saveToCache(List newQuestions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_image_questions', json.encode(newQuestions));
    cachedQuestionIds = newQuestions.map((q) => q['id'].toString()).toList();
  }

  Future<void> _updateQuestions() async {
    if (coins < 50) {
      _showSnack('تحتاج 50 💰 للتحديث');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final snapshot = await FirebaseFirestore.instance
        .collection('approved_image_questions')
        .limit(30)
        .get();

      List newQuestions = snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      newQuestions = newQuestions.where((q) =>!cachedQuestionIds.contains(q['id'])).toList();

      if (newQuestions.isEmpty) {
        _showSnack('لا توجد أسئلة صورية جديدة');
        setState(() => _isUpdating = false);
        return;
      }

      await _saveToCache(newQuestions);
      coins -= 50;
      await _saveCoins();
      await _syncCoinsToFirebase();

      setState(() {
        questions = newQuestions;
        questions.shuffle();
        currentQ = 0;
        correctAnswers = 0;
        _isUpdating = false;
      });

      _setupQuestion();
      _startTimer();
      _showSnack('✅ تم التحديث! ${newQuestions.length} سؤال جديد');

    } catch (e) {
      _showSnack('❌ فشل التحديث - تأكد من الاتصال');
      setState(() => _isUpdating = false);
    }
  }

  void _setupQuestion() {
    if (questions.isEmpty || currentQ >= questions.length) return;
    var q = questions[currentQ];
    String answer = q['answer']?? '';
    if (answer.isEmpty) return;

    List<String> letters = answer.split('');
    letters.shuffle();

    List<String> extra = ['ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي'];
    extra.shuffle();
    letters.addAll(extra.take(6));
    letters.shuffle();

    setState(() {
      availableLetters = letters;
      userAnswer = List.filled(answer.length, '');
      usedLetters = List.filled(letters.length, false);
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        coins = prefs.getInt('coins')?? 0;
        gems = prefs.getInt('gems')?? 0;
      });
    }
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

  void _addLetter(int index) {
    if (usedLetters[index] || index >= availableLetters.length) return;
    for (int i = 0; i < userAnswer.length; i++) {
      if (userAnswer[i] == '') {
        setState(() {
          userAnswer[i] = availableLetters[index];
          usedLetters[index] = true;
        });
        _checkAnswer();
        break;
      }
    }
  }

  void _removeLetter(int index) {
    if (index >= userAnswer.length || userAnswer[index] == '') return;
    String letter = userAnswer[index];
    for (int i = 0; i < availableLetters.length; i++) {
      if (availableLetters[i] == letter && usedLetters[i]) {
        setState(() {
          usedLetters[i] = false;
          userAnswer[index] = '';
        });
        break;
      }
    }
  }

  void _checkAnswer() {
    if (userAnswer.contains('')) return;
    _timer?.cancel();
    String answer = userAnswer.join();
    String correctAnswer = questions[currentQ]['answer']?? '';

    if (answer == correctAnswer) {
      coins += 15;
      correctAnswers++;
      _saveCoins();
      _syncCoinsToFirebase();
      _showSnack('✅ صحيح! +15 عملة');
    } else {
      _showSnack('❌ خطأ - الجواب: $correctAnswer');
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion(answer == correctAnswer);
    });
  }

  void _nextQuestion(bool wasCorrect) {
    if (!mounted) return;
    if (currentQ < questions.length - 1) {
      setState(() => currentQ++);
      _setupQuestion();
      _startTimer();
    } else {
      _endQuiz();
    }
  }

  Future<void> _syncCoinsToFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? playerName = prefs.getString('playerName');
      if (playerName == null) return;
      await FirebaseFirestore.instance.collection('players').doc(playerName).update({'coins': coins});
    } catch (e) {
      print('أوفلاين');
    }
  }

  void _useHelp(String type) async {
    if (userAnswer.where((e) => e!= '').isEmpty && type!= 'skip' && type!= 'friend') {
      _showSnack('ابدأ الإجابة أولاً');
      return;
    }
    if (type == 'skip' || type == 'friend') {
      _executeHelp(type);
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استخدام مساعدة'),
        content: Text(type == 'remove'? 'حذف أحرف - 30 💰' : type == 'pause'? 'إيقاف المؤقت - 30 💰' : 'كشف حرف - 20 💰'),
        actions: [
          TextButton(
            onPressed: () {
              int cost = type == 'reveal'? 20 : 30;
              if (coins >= cost) {
                coins -= cost;
                _saveCoins();
                _syncCoinsToFirebase();
                Navigator.pop(context);
                _executeHelp(type);
              } else {
                _showSnack('عملات غير كافية');
              }
            },
            child: Text('استخدم ${type == 'reveal'? 20 : 30} 💰'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnack('شاهد إعلان - قريباً');
              _executeHelp(type);
            },
            child: const Text('شاهد إعلان'),
          ),
        ],
      ),
    );
  }

  void _executeHelp(String type) {
    if (questions.isEmpty || currentQ >= questions.length) return;
    var q = questions[currentQ];
    String correctAnswer = q['answer']?? '';
    switch (type) {
      case 'skip':
        _showSnack('تم التخطي');
        _nextQuestion(false);
        break;
      case 'friend':
        String hint = q['hint']?? '4 صور مشتركة';
        Share.share('ساعدني في تحدي العباقرة:\n4 صور تدل على: $hint');
        break;
      case 'remove':
        int removed = 0;
        for (int i = 0; i < availableLetters.length && removed < 4; i++) {
          if (!usedLetters[i] &&!correctAnswer.contains(availableLetters[i])) {
            setState(() => usedLetters[i] = true);
            removed++;
          }
        }
        _showSnack('تم حذف $removed أحرف');
        break;
      case 'pause':
        _timer?.cancel();
        _showSnack('تم إيقاف المؤقت 30 ثانية');
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && userAnswer.contains('')) _startTimer();
        });
        break;
      case 'reveal':
        for (int i = 0; i < userAnswer.length; i++) {
          if (userAnswer[i] == '') {
            String correctLetter = correctAnswer[i];
            for (int j = 0; j < availableLetters.length; j++) {
              if (availableLetters[j] == correctLetter &&!usedLetters[j]) {
                _addLetter(j);
                _showSnack('تم كشف حرف');
                return;
              }
            }
          }
        }
        _showSnack('لا توجد خانات فارغة');
        break;
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
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('خلصت الأسئلة الصورية! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('أجبت صحيح: $correctAnswers / ${questions.length}'),
            Text('ربحت: ${correctAnswers * 15} عملة'),
            const SizedBox(height: 20),
            const Text('تبغى أسئلة جديدة؟', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            onPressed: _isUpdating? null : () {
              Navigator.pop(context);
              _updateQuestions();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: _isUpdating
             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تحديث - 50 💰', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])),
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('أسئلة صورية'), backgroundColor: const Color(0xFF6A11CB)),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('لا توجد أسئلة', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _updateQuestions, child: const Text('تحديث الأسئلة')),
          ]),
        ),
      );
    }

    var q = questions[currentQ];

    return WillPopScope(
      onWillPop: () async {
        _timer?.cancel();
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('أسئلة صورية'),
          backgroundColor: const Color(0xFF6A11CB),
          actions: [
            Center(child: Text('$timer ⏱ ', style: const TextStyle(fontSize: 18))),
            Center(child: Text('$coins 💰 ', style: const TextStyle(fontSize: 16))),
            Center(child: Text('$gems 💎 ', style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 10),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _helpBtn('تخطي', Icons.skip_next, () => _useHelp('skip')),
                    _helpBtn('اسأل صديق', Icons.share, () => _useHelp('friend')),
                    _helpBtn('حذف أحرف', Icons.delete, () => _useHelp('remove')),
                    _helpBtn('إيقاف', Icons.pause, () => _useHelp('pause')),
                    _helpBtn('كشف حرف', Icons.visibility, () => _useHelp('reveal')),
                  ]),
                ),
                const SizedBox(height: 15),
                Text('السؤال ${currentQ + 1} / ${questions.length}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 10),
                Text(q['hint']?? '4 صور مشتركة', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  flex: 3,
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: List.generate(4, (index) {
                      return Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))]),
                        child: Center(child: Text(q['images']?[index]?? '❓', style: const TextStyle(fontSize: 60))),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(userAnswer.length, (index) {
                    return GestureDetector(
                      onTap: () => _removeLetter(index),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber, width: 2)),
                        child: Center(child: Text(userAnswer[index], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 15),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: List.generate(availableLetters.length, (index) {
                        return GestureDetector(
                          onTap: usedLetters[index]? null : () => _addLetter(index),
                          child: Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(color: usedLetters[index]? Colors.grey.shade400 : Colors.amber, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text(availableLetters[index], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: usedLetters[index]? Colors.grey.shade600 : Colors.black))),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _helpBtn(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
      ),
    );
  }
}