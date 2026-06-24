import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String myName = '';
  String myTitle = '';
  int myAvatar = 0;
  int myCoins = 0;
  int myRank = 0;

  // أيقونات الصور الرمزية
  final List<IconData> avatarIcons = [
    Icons.boy, Icons.person, Icons.woman, Icons.man, Icons.person_4, Icons.girl
  ];

  // جوائز الأسبوع: جمعة → خميس
  final Map<int, int> weeklyPrizes = {
    1: 500, 2: 300, 3: 200,
    4: 100, 5: 100, 6: 100, 7: 100, 8: 100, 9: 100, 10: 100, 11: 100, 12: 100, 13: 100,
  };

  @override
  void initState() {
    super.initState();
    _loadMyData();
    _updateMyScore();
  }

  void _loadMyData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myName = prefs.getString('playerName')?? 'لاعب';
      myTitle = prefs.getString('title')?? 'العبقري المبتدأ';
      myAvatar = prefs.getInt('playerAvatar')?? 0;
      myCoins = prefs.getInt('coins')?? 0;
    });
  }

  // رفع نتيجتي للـ Firebase
  void _updateMyScore() async {
    final prefs = await SharedPreferences.getInstance();
    String playerId = prefs.getString('playerId')?? DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString('playerId', playerId);

    await FirebaseFirestore.instance.collection('leaderboard').doc(playerId).set({
      'name': myName,
      'title': myTitle,
      'avatar': myAvatar,
      'coins': myCoins,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _getWeekDate() {
    DateTime now = DateTime.now();
    // الجمعة بداية الأسبوع
    DateTime friday = now.subtract(Duration(days: (now.weekday + 1) % 7));
    DateTime thursday = friday.add(Duration(days: 6));
    return '${friday.day}/${friday.month} - ${thursday.day}/${thursday.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الصدارة'),
        backgroundColor: Color(0xFF6A11CB),
        actions: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text('أسبوع ${_getWeekDate()}', style: TextStyle(fontSize: 12)),
            ),
          ),
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
          children: [
            // خانتي أنا
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(avatarIcons[myAvatar], size: 40, color: Color(0xFF6A11CB)),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(myName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(myTitle, style: TextStyle(fontSize: 14, color: Colors.amber)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('$myCoins', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('عملة', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),

            // الجوائز
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPrizeItem('🥇', '500'),
                  _buildPrizeItem('🥈', '300'),
                  _buildPrizeItem('🥉', '200'),
                  _buildPrizeItem('4-13', '100'),
                  _buildPrizeItem('14-100', '50'),
                ],
              ),
            ),
            SizedBox(height: 10),

            // قائمة اللاعبين أونلاين
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                   .collection('leaderboard')
                   .orderBy('coins', descending: true)
                   .limit(100)
                   .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  var players = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      var player = players[index].data() as Map<String, dynamic>;
                      int rank = index + 1;
                      bool isMe = player['name'] == myName;

                      if (isMe) myRank = rank;

                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMe? Colors.amber.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: rank == 1? Colors.amber : rank == 2? Colors.grey : rank == 3? Colors.brown : Colors.transparent,
                            width: rank <= 3? 2 : 0,
                          ),
                        ),
                        child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 35,
                                child: Text(
                                  rank <= 3? ['🥇','🥈','🥉'][rank-1] : '#$rank',
                                  style: TextStyle(fontSize: rank <= 3? 24 : 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              SizedBox(width: 10),
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(avatarIcons[player['avatar']?? 0], color: Color(0xFF6A11CB)),
                              ),
                            ],
                          ),
                          title: Text(
                            player['name']?? 'لاعب',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            player['title']?? 'العبقري المبتدأ',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${player['coins']?? 0}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                              Text('عملة', style: TextStyle(fontSize: 10, color: Colors.white70)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeItem(String rank, String prize) {
    return Column(
      children: [
        Text(rank, style: TextStyle(fontSize: 20)),
        Text('$prize 💰', style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}