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
  List<String> cachedQuestionIds = []; // لتتبع الأسئلة المكررة
  int currentQ = 0;
  int coins = 0;
  int gems = 0;
  int correctAnswers = 0;
  int timer = 30;
  Timer? _timer;
  bool showAnswer = false;
  List<int> disabledAnswers = [];
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
      _startTimer();
    }
    setState(() => _isLoading = false);
  }

  // يحمل الأسئلة: 1. من الكاش 2. من assets لو الكاش فاضي
  Future<void> _loadQuestions() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. جرب تحمل من الكاش أولاً
    String? cachedData = prefs.getString('cached_questions_${widget.category}');
    List allQ = [];

    if (cachedData!= null) {
      allQ = json.decode(cachedData);
      cachedQuestionIds = allQ.map((q) => q['id'].toString()).toList();
    } else {
      // 2. لو مافي كاش، حمل من assets
      try {
        String data = await DefaultAssetBundle.of(context).loadString("assets/questions.json");
        List assetQ = json.decode(data);

        if (widget.category == 'عامة') {
          allQ = assetQ;
        } else {
          allQ = assetQ.where((q) => q['type'] == widget.category).toList();
        }
        // احفظ في الكاش أول مرة
        await _saveToCache(allQ);
      } catch (e) {
        print('خطأ في تحميل assets: $e');
      }
    }

    if (mounted) {
      setState(() {
        questions = allQ;
        questions.shuffle();
      });
    }
  }

  // يحفظ الأسئلة في الكاش
  Future<void> _saveToCache(List newQuestions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_questions_${widget.category}', json.encode(newQuestions));
    cachedQuestionIds = newQuestions.map((q) => q['id'].toString()).toList();
  }

  // تحديث الأسئلة من Firebase - يحذف القديم ويجيب جديد
  Future<void> _updateQuestions() async {
    if (coins < 50) {
      _showSnack('تحتاج 50 💰 للتحديث');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // 1. جيب أسئلة جديدة من Firebase غير مكررة
      final snapshot = await FirebaseFirestore.instance
         .collection('approved_questions')
         .where('type', isEqualTo: widget.category == 'عامة'? null : widget.category)
         .limit(50)
         .get();

      List newQuestions = snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id; // ضيف ID عشان نمنع التكرار
        return data;
      }).toList();

      // 2. احذف الأسئلة المكررة
      newQuestions = newQuestions.where((q) =>!cachedQuestionIds.contains(q['id'])).toList();

      if (newQuestions.isEmpty) {
        _showSnack('لا توجد أسئلة جديدة حالياً');
        setState(() => _isUpdating = false);
        return;
      }

      // 3. احذف الكاش القديم واحفظ الجديد
      await _saveToCache(newQuestions);

      // 4. اخصم العملات
      coins -= 50;
      await _saveCoins();

      setState(() {
        questions = newQuestions;
        questions.shuffle();
        currentQ = 0;
        correctAnswers = 0;
        showAnswer = false;
        disabledAnswers.clear();
        _isUpdating = false;
      });

      _startTimer();
      _showSnack('✅ تم التحديث! ${newQuestions.length} سؤال جديد');

    } catch (e) {
      _showSnack('❌ فشل التحديث - تأكد من الاتصال');
      setState(() => _isUpdating = false);
    }
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

  void _checkAnswer(int index) {
    if (showAnswer) return;
    _timer?.cancel();
    bool correct = index == questions[currentQ]['correct'];
    if (correct) {
      coins += 10;
      correctAnswers++;
      _saveCoins();
      _syncCoinsToFirebase(); // يرفع للسيرفر لو فيه نت
    }
    setState(() => showAnswer = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion(correct);
    });
  }

  void _nextQuestion(bool wasCorrect) {
    if (!mounted) return;

    if (currentQ < questions.length - 1) {
      setState(() {
        currentQ++;
        showAnswer = false;
        disabledAnswers.clear();
      });
      _startTimer();

      if ((currentQ + 1) % 20 == 0) {
        gems += 10;
        _saveGems();
        _syncGemsToFirebase();
        _showSnack('🎉 مبروك! أنهيت مرحلة +10 مجوهرات');
      }
    } else {
      _endQuiz();
    }
  }

  // مزامنة العملات مع Firebase لو فيه نت
  Future<void> _syncCoinsToFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? playerName = prefs.getString('playerName');
      if (playerName == null) return;

      await FirebaseFirestore.instance.collection('players').doc(playerName).update({'coins': coins});
    } catch (e) {
      print('أوفلاين - ما قدر يزامن العملات');
    }
  }

  Future<void> _syncGemsToFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? playerName = prefs.getString('playerName');
      if (playerName == null) return;

      await FirebaseFirestore.instance.collection('players').doc(playerName).update({'gems': gems});
    } catch (e) {
      print('أوفلاين - ما قدر يزامن المجوهرات');
    }
  }

  void _useHelp(String type) async {
    if (showAnswer) return;

    if (type == 'skip' || type == 'friend') {
      _executeHelp(type);
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استخدام مساعدة'),
        content: Text(type == 'remove2'? 'حذف إجابتين - 30 💰' : type == 'pause'? 'إيقاف المؤقت - 30 💰' : 'تلميح - 20 💰'),
        actions: [
          TextButton(
            onPressed: () {
              int cost = type == 'hint'? 20 : 30;
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
            child: Text('استخدم ${type == 'hint'? 20 : 30} 💰'),
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
    switch (type) {
      case 'skip':
        _showSnack('تم التخطي');
        _nextQuestion(false);
        break;
      case 'friend':
        Share.share('ساعدني بهذا السؤال: ${questions[currentQ]['q']}');
        break;
      case 'remove2':
        List<int> wrongAnswers = [];
        for (int i = 0; i < 4; i++) {
          if (i!= questions[currentQ]['correct']) wrongAnswers.add(i);
        }
        wrongAnswers.shuffle();
        setState(() => disabledAnswers = wrongAnswers.take(2).toList());
        break;
      case 'pause':
        _timer?.cancel();
        _showSnack('تم إيقاف المؤقت 30 ثانية');
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted &&!showAnswer) _startTimer();
        });
        break;
      case 'hint':
        String answer = questions[currentQ]['a'][questions[currentQ]['correct']];
        _showSnack('تلميح: الجواب يبدأ بحرف ${answer[0]}');
        break;
    }
  }

  Future<void> _saveCoins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
  }

  Future<void> _saveGems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gems', gems);
  }

  // نهاية الأسئلة - يطلع زر التحديث بدل "انتهت"
  void _endQuiz() {
    _timer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('خلصت كل الأسئلة! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('أجبت صحيح: $correctAnswers / ${questions.length}'),
            Text('ربحت: ${correctAnswers * 10} عملة'),
            Text('المجوهرات: $gems 💎'),
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
                : const Text('تحديث الأسئلة - 50 💰', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
          ),
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category), backgroundColor: const Color(0xFF6A11CB)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('لا توجد أسئلة', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateQuestions,
                child: const Text('تحديث الأسئلة'),
              ),
            ],
          ),
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
          title: Text(widget.category),
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
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _helpBtn('تخطي', Icons.skip_next, () => _useHelp('skip')),
                      _helpBtn('اسأل صديق', Icons.share, () => _useHelp('friend')),
                      _helpBtn('حذف 2', Icons.delete, () => _useHelp('remove2')),
                      _helpBtn('إيقاف', Icons.pause, () => _useHelp('pause')),
                      _helpBtn('تلميح', Icons.lightbulb, () => _useHelp('hint')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('السؤال ${currentQ + 1} / ${questions.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      q['q'],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      bool isCorrect = index == q['correct'];
                      bool isDisabled = disabledAnswers.contains(index);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ElevatedButton(
                          onPressed: isDisabled || showAnswer? null : () => _checkAnswer(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showAnswer
                              ? isCorrect? Colors.green : Colors.red
                                : isDisabled? Colors.grey.shade400 : Colors.white,
                            padding: const EdgeInsets.all(18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text(
                            q['a'][index],
                            style: TextStyle(
                              fontSize: 18,
                              color: showAnswer || isDisabled? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
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
        onPressed: showAnswer? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}