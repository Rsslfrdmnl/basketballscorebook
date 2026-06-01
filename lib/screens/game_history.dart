import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class GameHistory extends StatefulWidget {
  const GameHistory({super.key});

  @override
  State<GameHistory> createState() => _GameHistoryState();
}

class _GameHistoryState extends State<GameHistory> {
  String selectedDivision = '14U';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                _buildDivisionTab('14U', Icons.child_care, AppTheme.accentBlue),
                const SizedBox(width: 12),
                _buildDivisionTab('16U', Icons.people, AppTheme.accentGreen),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .where('division', isEqualTo: selectedDivision)
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: const Icon(
                      Icons.history,
                      size: 48,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No games in ${selectedDivision} division',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final game = snapshot.data!.docs[index];
              final data = game.data() as Map<String, dynamic>;
              
              final homeScore = data['homeScore'] ?? 0;
              final awayScore = data['awayScore'] ?? 0;
              final homeTeam = data['homeTeam'] ?? 'Home';
              final awayTeam = data['awayTeam'] ?? 'Away';
              final date = data['date']?.toDate() ?? DateTime.now();
              final quarter = data['quarter'] ?? 1;
              
              String winnerText;
              Color winnerColor;
              if (homeScore > awayScore) {
                winnerText = '$homeTeam Wins!';
                winnerColor = AppTheme.accentGreen;
              } else if (awayScore > homeScore) {
                winnerText = '$awayTeam Wins!';
                winnerColor = AppTheme.accentGreen;
              } else {
                winnerText = 'Tie Game';
                winnerColor = AppTheme.accentGold;
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.cardDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accentBlue.withOpacity(0.2)),
                        ),
                        child: Text(
                          'Q$quarter',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$homeTeam vs $awayTeam',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${date.month}/${date.day}/${date.year}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$homeScore - $awayScore',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.accentGold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        winnerText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: winnerColor,
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
                          quarter: quarter,
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

  Widget _buildDivisionTab(String division, IconData icon, Color color) {
    final isSelected = selectedDivision == division;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedDivision = division;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
              ? color.withOpacity(0.1)
              : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected 
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? color : AppTheme.textMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                division,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Score header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(
                              widget.homeTeam,
                              style: const TextStyle(
                                color: AppTheme.homeTeam,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.homeScore.toString(),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'Q${widget.quarter}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${widget.date.month}/${widget.date.day}/${widget.date.year}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              widget.awayTeam,
                              style: const TextStyle(
                                color: AppTheme.awayTeam,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.awayScore.toString(),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
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
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.amber.withOpacity(0.15),
                            Colors.amber.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🏆 MVP of the Game',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mvpData!['name'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${mvpData!['team']} • ${mvpData!['points']} pts • ${mvpData!['fouls']} fls',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Center(
                        child: Text(
                          'No MVP data available',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
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
                            'Player Stats',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(mvpData!['players'] as Map<String, dynamic>).entries.map((entry) {
                            final player = entry.value;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: AppTheme.cardDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: player['points'] == mvpData!['points'] 
                                      ? Colors.amber.withOpacity(0.2)
                                      : AppTheme.surfaceDark,
                                  child: Text(
                                    player['name'][0].toUpperCase(),
                                    style: TextStyle(
                                      color: player['points'] == mvpData!['points'] 
                                          ? Colors.amber
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  player['name'],
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  player['team'],
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${player['points']} pts',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accentGold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${player['fouls']} fls',
                                      style: const TextStyle(
                                        color: AppTheme.accentRed,
                                      ),
                                    ),
                                  ],
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