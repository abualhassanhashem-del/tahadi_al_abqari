import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int coins = 0;
  int gems = 0;
  String currentTitle = 'العبقري المبتدأ';
  int playerLevel = 1;
  List<String> ownedTitles = ['العبقري المبتدأ'];
  String playerId = '';

  final List<Map<String, dynamic>> allTitles = [
    {'name': 'العبقري المبتدأ', 'price': 0, 'type': 'free', 'ads': 0, 'level': 1},
    {'name': 'العبقري الباحث', 'price': 0, 'type': 'free', 'ads': 0, 'level': 2},
    {'name': 'العبقري الناشئ', 'price': 100, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري المجتهد', 'price': 200, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري المثابر', 'price': 300, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري الذكي', 'price': 400, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري السريع', 'price': 500, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري اللماح', 'price': 600, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري الفطن', 'price': 700, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري النبيه', 'price': 800, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري اليقظ', 'price': 900, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري الحاذق', 'price': 1000, 'type': 'coin', 'ads': 1},
    {'name': 'العبقري الخبير', 'price': 1200, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري العالم', 'price': 1400, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الحكيم', 'price': 1600, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري المفكر', 'price': 1800, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الفيلسوف', 'price': 2000, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري المبدع', 'price': 2200, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري المبتكر', 'price': 2400, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري المخترع', 'price': 2600, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري العلامة', 'price': 2800, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري النابغة', 'price': 3000, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الجهبذ', 'price': 3200, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الألمعي', 'price': 3400, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري اللوذعي', 'price': 3600, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الداهية', 'price': 3800, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري العبقري', 'price': 4000, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري النجم', 'price': 4200, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الكوكب', 'price': 4400, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري المجرة', 'price': 4600, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الفضاء', 'price': 4800, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الكون', 'price': 5000, 'type': 'coin', 'ads': 2},
    {'name': 'العبقري الأسطورة', 'price': 5500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الخارق', 'price': 6000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الجبار', 'price': 6500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري المدمر', 'price': 7000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري القاهر', 'price': 7500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري المسيطر', 'price': 8000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الملك', 'price': 8500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري السلطان', 'price': 9000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الإمبراطور', 'price': 9500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري القيصر', 'price': 10000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الفرعون', 'price': 10500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الكاسر', 'price': 11000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري السفاح', 'price': 11500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الجلاد', 'price': 12000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الوحش', 'price': 12500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري التنين', 'price': 13000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الإعصار', 'price': 13500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري البركان', 'price': 14000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الزلزال', 'price': 14500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الرعد', 'price': 15000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري البرق', 'price': 15500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الصاعقة', 'price': 16000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري النيزك', 'price': 16500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الشهاب', 'price': 17000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري المذنب', 'price': 17500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الثقب الأسود', 'price': 18000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري المستعر', 'price': 18500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري السوبرنوفا', 'price': 19000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري العملاق الأحمر', 'price': 19500, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري القزم الأبيض', 'price': 20000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري النجم النيوتروني', 'price': 21000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الكوازار', 'price': 22000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري البلازار', 'price': 23000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري السديم', 'price': 24000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري العنقود', 'price': 25000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الذراع المجري', 'price': 26000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الكون الموازي', 'price': 27000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري الأكوان المتعددة', 'price': 28000, 'type': 'coin', 'ads': 3},
    {'name': 'العبقري حاكم الزمن', 'price': 5, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري سيد المجرات', 'price': 10, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري إله المعرفة', 'price': 15, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري ملك العباقرة', 'price': 20, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري الخالد', 'price': 25, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري المطلق', 'price': 30, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري الأبدي', 'price': 35, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري الكوني', 'price': 40, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري السرمدي', 'price': 45, 'type': 'gem', 'ads': 0},
    {'name': 'العبقري اللامحدود', 'price': 50, 'type': 'gem', 'ads': 0},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    playerId = p.getString('playerId') ?? '';
    setState(() {
      coins = p.getInt('coins') ?? 200;
      gems = p.getInt('gems') ?? 0;
      currentTitle = p.getString('title') ?? 'العبقري المبتدأ';
      ownedTitles = p.getStringList('ownedTitles') ?? ['العبقري المبتدأ'];
      playerLevel = p.getInt('level') ?? 1;
    });
    if (playerId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('players').doc(playerId).get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          coins = d['coins'] ?? coins;
          gems = d['gems'] ?? gems;
          currentTitle = d['title'] ?? currentTitle;
          ownedTitles = List<String>.from(d['titles'] ?? ownedTitles);
        });
      }
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('coins', coins);
    await p.setInt('gems', gems);
    await p.setString('title', currentTitle);
    await p.setStringList('ownedTitles', ownedTitles);
    if (playerId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('players').doc(playerId).set({
        'coins': coins,
        'gems': gems,
        'title': currentTitle,
        'titles': ownedTitles,
      }, SetOptions(merge: true));
    }
  }

  void _buy(Map<String, dynamic> t) async {
    if (ownedTitles.contains(t['name'])) {
      setState(() => currentTitle = t['name']);
      await _save();
      _snack('تم تجهيز: ${t['name']}');
      return;
    }
    if (t['type'] == 'free') {
      if (playerLevel >= t['level']) {
        ownedTitles.add(t['name']);
        currentTitle = t['name'];
        setState(() {});
        await _save();
        _snack('مبروك ${t['name']}');
      } else {
        _snack('يفتح في المرحلة ${t['level']}');
      }
      return;
    }
    if (t['type'] == 'coin') {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: Text(t['name']),
        content: Text('${t['price']} عملة أو شاهد ${t['ads']} إعلان'),
        actions: [
          TextButton(onPressed: () async {
            Navigator.pop(context);
            if (coins >= t['price']) {
              coins -= t['price'] as int;
              ownedTitles.add(t['name']);
              currentTitle = t['name'];
              setState(() {});
              await _save();
              _snack('تم الشراء');
            } else _snack('عملات غير كافية');
          }, child: const Text('شراء')),
          TextButton(onPressed: () async {
            Navigator.pop(context);
            ownedTitles.add(t['name']);
            currentTitle = t['name'];
            setState(() {});
            await _save();
            _snack('شاهدت الإعلان - مبروك');
          }, child: Text('إعلان')),
        ],
      ));
    } else {
      if (gems >= t['price']) {
        gems -= t['price'] as int;
        ownedTitles.add(t['name']);
        currentTitle = t['name'];
        setState(() {});
        await _save();
        _snack('VIP مبروك');
      } else _snack('مجوهرات غير كافية');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('متجر الألقاب'), backgroundColor: const Color(0xFF6A11CB), actions: [
        Padding(padding: const EdgeInsets.all(12), child: Text('$coins 💰  $gems 💎')),
      ]),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(12), color: Colors.amber.withOpacity(0.2), child: Column(children: [
          const Text('لقبك الحالي'),
          Text(currentTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber[800])),
        ])),
        Expanded(child: ListView.builder(itemCount: allTitles.length, itemBuilder: (_, i) {
          final t = allTitles[i];
          final owned = ownedTitles.contains(t['name']);
          final current = currentTitle == t['name'];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: current ? Colors.amber.shade50 : null, child: ListTile(
            leading: Icon(t['type']=='gem'?Icons.workspace_premium:t['type']=='free'?Icons.star:Icons.monetization_on, color: t['type']=='gem'?Colors.purple:t['type']=='free'?Colors.green:Colors.amber),
            title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(owned?(current?'مستخدم':'مملوك'):t['type']=='free'?'مرحلة ${t['level']}':t['type']=='gem'?'${t['price']} 💎':'${t['price']} 💰'),
            trailing: ElevatedButton(onPressed: () => _buy(t), style: ElevatedButton.styleFrom(backgroundColor: owned?(current?Colors.orange:Colors.green):const Color(0xFF6A11CB)), child: Text(owned?(current?'مستخدم':'تجهيز'):'شراء')),
          ));
        })),
      ]),
    );
  }
}