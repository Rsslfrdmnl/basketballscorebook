import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameHistory extends StatelessWidget {
  const GameHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        backgroundColor: const Color.fromARGB(255, 228, 148, 28),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading games'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No games played yet'));
          }
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final game = snapshot.data!.docs[index];
              final data = game.data() as Map<String, dynamic>;
              
              // Determine winner
              final homeScore = data['homeScore'] ?? 0;
              final awayScore = data['awayScore'] ?? 0;
              final homeTeam = data['homeTeam'] ?? 'Home';
              final awayTeam = data['awayTeam'] ?? 'Away';
              final date = data['date']?.toDate() ?? DateTime.now();
              
              String winnerText;
              Color winnerColor;
              if (homeScore > awayScore) {
                winnerText = '$homeTeam Wins!';
                winnerColor = Colors.green;
              } else if (awayScore > homeScore) {
                winnerText = '$awayTeam Wins!';
                winnerColor = Colors.green;
              } else {
                winnerText = 'Tie Game';
                winnerColor = Colors.orange;
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('$homeTeam vs $awayTeam'),
                  subtitle: Text(
                    '${date.month}/${date.day}/${date.year} • Q${data['quarter']}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$homeScore - $awayScore',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        winnerText,
                        style: TextStyle(
                          fontSize: 12,
                          color: winnerColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameDetailScreen(
                          gameId: game.id,
                          homeTeam: homeTeam,
                          awayTeam: awayTeam,
                          homeScore: homeScore,
                          awayScore: awayScore,
                          quarter: data['quarter'],
                          date: date,
                          homeTeamId: data['homeTeamId'] ?? '',
                          awayTeamId: data['awayTeamId'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GameDetailScreen extends StatefulWidget {
  final String gameId;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final int quarter;
  final DateTime date;
  final String homeTeamId;
  final String awayTeamId;

  const GameDetailScreen({
    super.key,
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.quarter,
    required this.date,
    required this.homeTeamId,
    required this.awayTeamId,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  Map<String, dynamic>? mvpData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateMVP();
  }

  Future<void> _calculateMVP() async {
    // Get all player stats for this game
    final statsSnapshot = await FirebaseFirestore.instance
        .collection('player_stats')
        .where('gameId', isEqualTo: widget.gameId)
        .get();
    
    if (statsSnapshot.docs.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Calculate MVP based on points
    String? mvpPlayerId;
    String? mvpPlayerName;
    int maxPoints = 0;
    int mvpFouls = 0;
    String mvpTeam = '';

    // Map to store player stats
    Map<String, Map<String, dynamic>> playerStats = {};

    for (var doc in statsSnapshot.docs) {
      final data = doc.data();
      final playerId = data['playerId'];
      final points = data['points'] ?? 0;
      final fouls = data['fouls'] ?? 0;
      
      // Get player name
      final playerDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(data['teamId'])
          .collection('players')
          .doc(playerId)
          .get();
      
      final playerName = playerDoc.exists ? playerDoc['name'] : 'Unknown';
      final teamId = data['teamId'];
      final teamName = teamId == widget.homeTeamId ? widget.homeTeam : widget.awayTeam;

      playerStats[playerId] = {
        'name': playerName,
        'points': points,
        'fouls': fouls,
        'team': teamName,
        'q1': data['quarter1'] ?? 0,
        'q2': data['quarter2'] ?? 0,
        'q3': data['quarter3'] ?? 0,
        'q4': data['quarter4'] ?? 0,
      };

      // Check if this player has more points
      if (points > maxPoints) {
        maxPoints = points;
        mvpPlayerId = playerId;
        mvpPlayerName = playerName;
        mvpFouls = fouls;
        mvpTeam = teamName;
      } else if (points == maxPoints && mvpPlayerId != null) {
        // Tie breaker: fewer fouls wins
        if (fouls < mvpFouls) {
          mvpPlayerId = playerId;
          mvpPlayerName = playerName;
          mvpFouls = fouls;
          mvpTeam = teamName;
        }
      }
    }

    // Save MVP to game document
    if (mvpPlayerId != null) {
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .update({
        'mvp': mvpPlayerId,
        'mvpName': mvpPlayerName,
        'mvpPoints': maxPoints,
        'mvpTeam': mvpTeam,
      });
    }

    setState(() {
      mvpData = {
        'name': mvpPlayerName ?? 'No MVP',
        'points': maxPoints,
        'fouls': mvpFouls,
        'team': mvpTeam,
        'players': playerStats,
      };
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.homeTeam} vs ${widget.awayTeam}'),
        backgroundColor: const Color.fromARGB(255, 228, 148, 28),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Score header
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.grey[900],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(widget.homeTeam, style: const TextStyle(color: Colors.white, fontSize: 18)),
                            Text(
                              widget.homeScore.toString(),
                              style: const TextStyle(color: Colors.blue, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text('Q${widget.quarter}', style: const TextStyle(color: Colors.white, fontSize: 18)),
                            Text(
                              '${widget.date.month}/${widget.date.day}/${widget.date.year}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(widget.awayTeam, style: const TextStyle(color: Colors.white, fontSize: 18)),
                            Text(
                              widget.awayScore.toString(),
                              style: const TextStyle(color: Colors.red, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // MVP Section
                  if (mvpData != null && mvpData!['name'] != 'No MVP')
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
  '🏆 MVP of the Game',
  style: TextStyle(
    fontSize: 20, 
    fontWeight: FontWeight.bold, 
    color: Colors.amber[800],
  ),
),
                          const SizedBox(height: 8),
                          Text(
                            mvpData!['name'],
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${mvpData!['team']} • ${mvpData!['points']} points • ${mvpData!['fouls']} fouls',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('No MVP data available', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Player Stats
                  if (mvpData != null && mvpData!['players'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Player Stats',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...(mvpData!['players'] as Map<String, dynamic>).entries.map((entry) {
                            final player = entry.value;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                title: Text(player['name']),
                                subtitle: Text(player['team']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${player['points']} pts',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${player['fouls']} fls',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: player['points'] == mvpData!['points'] 
                                      ? Colors.amber 
                                      : Colors.grey[300],
                                  child: Text(
                                    player['name'][0].toUpperCase(),
                                    style: TextStyle(
                                      color: player['points'] == mvpData!['points'] 
                                          ? Colors.black 
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}