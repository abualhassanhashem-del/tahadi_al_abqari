import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  String question = '';
  List<String> answers = ['', '', '', ''];
  int correctIndex = 0;
  String category = 'عامة';
  String playerName = '';
  int coins = 0;
  bool _isLoading = false;

  final List<String> categories = ['عامة', 'تاريخ', 'حزورة', 'جغرافيا', 'رياضة', 'مدن'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      playerName = prefs.getString('playerName')?? 'لاعب';
      coins = prefs.getInt('coins')?? 0;
    });
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // التحقق من العملات
    if (coins < 50) {
      _showSnack('تحتاج 50 عملة لإرسال سؤال. رصيدك: $coins');
      return;
    }

    // التحقق من الكلمات السيئة
    if (_checkBadWords(question) || answers.any((a) => _checkBadWords(a))) {
      _showSnack('السؤال أو الأجوبة تحتوي كلمات غير مناسبة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // إرسال لـ Firebase - نوحد الاسم suggested_questions
      await FirebaseFirestore.instance.collection('suggested_questions').add({
        'q': question,
        'a': answers,
        'correct': correctIndex,
        'type': category,
        'author': playerName,
        'approved': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // خصم 50 عملة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('coins', coins - 50);

      if (mounted) {
        _showSnack('✅ تم إرسال سؤالك للمراجعة. تم خصم 50 عملة');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnack('❌ خطأ في الإرسال: تأكد من الإنترنت');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _checkBadWords(String text) {
    List<String> badWords = ['عنصرية', 'إرهاب', 'دين', 'سياسة', 'إباحي', 'سياسي', 'طائفي'];
    String lower = text.toLowerCase();
    return badWords.any((word) => lower.contains(word));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ضع سؤالك'),
        backgroundColor: const Color(0xFF6A11CB),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$coins 💰', style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('شروط السؤال - 50 عملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text('• لا عنصرية أو إرهاب أو إباحية\n• لا استغلال طفولة\n• لا مواضيع دينية أو سياسية\n• سؤال واضح ومفيد',
                        style: TextStyle(fontSize: 14), textAlign: TextAlign.right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // نوع السؤال
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'نوع السؤال',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => category = val!),
              ),
              const SizedBox(height: 15),

              // السؤال
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'اكتب السؤال',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                maxLines: 3,
                validator: (val) => val!.trim().isEmpty? 'اكتب السؤال' : null,
                onSaved: (val) => question = val!.trim(),
              ),
              const SizedBox(height: 15),

              // الأجوبة الأربعة
             ...List.generate(4, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: index,
                        groupValue: correctIndex,
                        onChanged: (val) => setState(() => correctIndex = val!),
                        fillColor: MaterialStateProperty.all(Colors.white),
                      ),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: index == correctIndex? 'الجواب الصحيح ✅' : 'جواب خاطئ ${index + 1} ❌',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          validator: (val) => val!.trim().isEmpty? 'اكتب الجواب' : null,
                          onSaved: (val) => answers[index] = val!.trim(),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading? null : _submitQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                   ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('إرسال للمراجعة - 50 💰', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}