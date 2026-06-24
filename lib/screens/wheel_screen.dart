import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class WheelScreen extends StatefulWidget {
  @override
  _WheelScreenState createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  int coins = 0;
  int gems = 0;
  int freeSpins = 3; // 3 لفات مجانية يومياً
  bool isSpinning = false;
  
  // 12 جائزة من 10 لـ 200 عملة + مجوهرات
  final List<Map<String, dynamic>> prizes = [
    {'value': 10, 'type': 'coin', 'color': Colors.red, 'label': '10 💰'},
    {'value': 20, 'type': 'coin', 'color': Colors.orange, 'label': '20 💰'},
    {'value': 30, 'type': 'coin', 'color': Colors.amber, 'label': '30 💰'},
    {'value': 50, 'type': 'coin', 'color': Colors.yellow, 'label': '50 💰'},
    {'value': 1, 'type': 'gem', 'color': Colors.cyan, 'label': '1 💎'},
    {'value': 70, 'type': 'coin', 'color': Colors.lightGreen, 'label': '70 💰'},
    {'value': 100, 'type': 'coin', 'color': Colors.green, 'label': '100 💰'},
    {'value': 2, 'type': 'gem', 'color': Colors.blue, 'label': '2 💎'},
    {'value': 120, 'type': 'coin', 'color': Colors.indigo, 'label': '120 💰'},
    {'value': 150, 'type': 'coin', 'color': Colors.purple, 'label': '150 💰'},
    {'value': 5, 'type': 'gem', 'color': Colors.pink, 'label': '5 💎'},
    {'value': 200, 'type': 'coin', 'color': Colors.redAccent, 'label': '200 💰'},
  ];

  double currentAngle = 0;
  int? winningIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(seconds: 4), vsync: this);
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String lastSpinDate = prefs.getString('lastSpinDate')?? '';
    String today = DateTime.now().toString().substring(0, 10);
    
    setState(() {
      coins = prefs.getInt('coins')?? 200;
      gems = prefs.getInt('gems')?? 0;
      // إذا يوم جديد = 3 لفات مجانية
      freeSpins = lastSpinDate == today? prefs.getInt('freeSpins')?? 3 : 3;
    });
    
    if (lastSpinDate!= today) {
      await prefs.setString('lastSpinDate', today);
      await prefs.setInt('freeSpins', 3);
    }
  }

  void _spinWheel() async {
    if (isSpinning) return;
    if (freeSpins <= 0) {
      _showAdForSpin();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isSpinning = true;
      freeSpins--;
    });
    await prefs.setInt('freeSpins', freeSpins);

    // اختيار عشوائي للجائزة
    final random = Random();
    winningIndex = random.nextInt(prizes.length);
    
    // حساب الزاوية: كل قطعة 30 درجة + لفات إضافية
    double segmentAngle = 360 / prizes.length;
    double targetAngle = 360 * 5 + (winningIndex! * segmentAngle) + segmentAngle / 2;
    
    _animation = Tween<double>(begin: currentAngle, end: currentAngle + targetAngle)
       .animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
    
    _controller.forward(from: 0).then((_) async {
      currentAngle += targetAngle;
      setState(() => isSpinning = false);
      
      // إضافة الجائزة
      var prize = prizes[winningIndex!];
      if (prize['type'] == 'coin') {
        coins += prize['value'] as int;
        await prefs.setInt('coins', coins);
      } else {
        gems += prize['value'] as int;
        await prefs.setInt('gems', gems);
      }
      setState(() {});
      
      _showWinDialog(prize);
    });
  }

  void _showAdForSpin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('انتهت اللفات المجانية'),
        content: Text('شاهد إعلان للحصول على لفة إضافية'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // هنا تربط AdMob بعدين
              setState(() => freeSpins = 1);
              _showSnack('تمت إضافة لفة مجانية');
            },
            child: Text('شاهد إعلان'),
          ),
        ],
      ),
    );
  }

  void _showWinDialog(Map<String, dynamic> prize) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.amber.shade100,
        title: Text('🎉 مبروووك 🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 80, color: Colors.orange),
            SizedBox(height: 20),
            Text('ربحت', style: TextStyle(fontSize: 20)),
            Text(prize['label'], style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: prize['color'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('رائع!', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('دولاب الحظ'),
        backgroundColor: Color(0xFF6A11CB),
        actions: [
          Center(child: Text('$coins 💰 ', style: TextStyle(fontSize: 16))),
          Center(child: Text('$gems 💎 ', style: TextStyle(fontSize: 16))),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('لفات مجانية: $freeSpins', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            
            // الدولاب
            Stack(
              alignment: Alignment.center,
              children: [
                // المؤشر
                Positioned(
                  top: 0,
                  child: Icon(Icons.arrow_drop_down, size: 60, color: Colors.red),
                ),
                // الدولاب
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: (_animation.value * pi / 180),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: CustomPaint(painter: WheelPainter(prizes)),
                  ),
                ),
                // زر الوسط
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Icon(Icons.star, size: 50, color: Colors.amber),
                ),
              ],
            ),
            
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: isSpinning? null : _spinWheel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                isSpinning? 'جاري الدوران...' : freeSpins > 0? 'لف الآن' : 'شاهد إعلان',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// رسم الدولاب
class WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> prizes;
  WheelPainter(this.prizes);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / prizes.length;
    
    for (int i = 0; i < prizes.length; i++) {
      final paint = Paint()..color = prizes[i]['color']..style = PaintingStyle.fill;
      final startAngle = i * segmentAngle - pi / 2;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );
      
      // كتابة النص
      final textPainter = TextPainter(
        text: TextSpan(
          text: prizes[i]['label'],
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.rtl,
      );
      textPainter.layout();
      
      final textAngle = startAngle + segmentAngle / 2;
      final textX = center.dx + (radius * 0.65) * cos(textAngle) - textPainter.width / 2;
      final textY = center.dy + (radius * 0.65) * sin(textAngle) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}