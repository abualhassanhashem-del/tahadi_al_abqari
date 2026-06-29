import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class WheelScreen extends StatefulWidget {
  @override
  _WheelScreenState createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int coins = 0;
  int gems = 0;
  int freeSpins = 3;
  bool isSpinning = false;

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

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);

    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toString().substring(0, 10);
    String lastSpinDate = prefs.getString('lastSpinDate') ?? '';

    setState(() {
      coins = prefs.getInt('coins') ?? 200;
      gems = prefs.getInt('gems') ?? 0;
      freeSpins = (lastSpinDate == today)
          ? (prefs.getInt('freeSpins') ?? 3)
          : 3;
    });

    if (lastSpinDate != today) {
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

    final random = Random();
    int winningIndex = random.nextInt(prizes.length);

    double segmentAngle = 360 / prizes.length;

    double targetAngle =
        360 * 5 + (winningIndex * segmentAngle) + segmentAngle / 2;

    _animation = Tween<double>(
      begin: currentAngle,
      end: currentAngle + targetAngle,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    );

    _controller.forward(from: 0).then((_) async {
      currentAngle += targetAngle;

      var prize = prizes[winningIndex];

      if (prize['type'] == 'coin') {
        coins += prize['value'] as int;
        await prefs.setInt('coins', coins);
      } else {
        gems += prize['value'] as int;
        await prefs.setInt('gems', gems);
      }

      setState(() {
        isSpinning = false;
      });

      _showWinDialog(prize);
    });
  }

  void _showAdForSpin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('انتهت اللفات المجانية'),
        content: const Text('شاهد إعلان للحصول على لفة إضافية'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => freeSpins = 1);
              _showSnack('تمت إضافة لفة مجانية');
            },
            child: const Text('شاهد إعلان'),
          ),
        ],
      ),
    );
  }

  void _showWinDialog(Map<String, dynamic> prize) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 مبروك', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 70, color: Colors.orange),
            const SizedBox(height: 10),
            Text(
              prize['label'],
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: prize['color'],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
        title: const Text('دولاب الحظ'),
        backgroundColor: const Color(0xFF6A11CB),
        actions: [
          Center(child: Text('$coins 💰 ')),
          Center(child: Text('$gems 💎 ')),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'لفات مجانية: $freeSpins',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(
                  top: 0,
                  child: Icon(Icons.arrow_drop_down,
                      size: 60, color: Colors.red),
                ),

                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animation.value * pi / 180,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 320,
                    height: 320,
                    child: CustomPaint(
                      painter: WheelPainter(prizes),
                    ),
                  ),
                ),

                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.star,
                      size: 50, color: Colors.amber),
                ),
              ],
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: isSpinning ? null : _spinWheel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
              ),
              child: Text(
                isSpinning ? 'جاري الدوران...' : 'لف الآن',
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> prizes;

  WheelPainter(this.prizes);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final paint = Paint()..color = prizes[i]['color'];

      final startAngle = i * segmentAngle - pi / 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: prizes[i]['label'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();

      final angle = startAngle + segmentAngle / 2;

      final x = center.dx + (radius * 0.65) * cos(angle);
      final y = center.dy + (radius * 0.65) * sin(angle);

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
