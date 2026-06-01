import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class LiveGameViewer extends StatelessWidget {
  const LiveGameViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Game'),
        backgroundColor: AppTheme.accentRed,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .where('status', isEqualTo: 'in_progress')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading game'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No live game in progress'),
                ],
              ),
            );
          }
          
          final gameDoc = snapshot.data!.docs.first;
          final gameData = gameDoc.data() as Map<String, dynamic>;
          final gameId = gameDoc.id;
          
          return LiveGameContent(gameId: gameId, gameData: gameData);
        },
      ),
    );
  }
}

class LiveGameContent extends StatelessWidget {
  final String gameId;
  final Map<String, dynamic> gameData;

  const LiveGameContent({
    super.key,
    required this.gameId,
    required this.gameData,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Score header - real-time from StreamBuilder
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('games')
                .doc(gameId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            data['homeTeam'] ?? 'Home',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.homeTeam,
                            ),
                          ),
                          Text(
                            data['homeScore'].toString() ?? '0',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Q${data['quarter'] ?? 1}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accentRed,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            data['awayTeam'] ?? 'Away',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.awayTeam,
                            ),
                          ),
                          Text(
                            data['awayScore'].toString() ?? '0',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          const SizedBox(height: 20),
          
          // Home team players - real-time
          _buildPlayerSection('Home Team', gameData['homeTeamId'], gameId),
          
          const SizedBox(height: 20),
          
          // Away team players - real-time
          _buildPlayerSection('Away Team', gameData['awayTeamId'], gameId),
        ],
      ),
    );
  }

  Widget _buildPlayerSection(String title, String teamId, String gameId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: title == 'Home Team' ? AppTheme.homeTeam : AppTheme.awayTeam,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .collection('players')
              .snapshots(),
          builder: (context, playerSnapshot) {
            if (!playerSnapshot.hasData) {
              return const Center(child: Text('Loading players...'));
            }
            
            // Get player stats for this game
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('player_stats')
                  .where('gameId', isEqualTo: gameId)
                  .snapshots(),
              builder: (context, statsSnapshot) {
                Map<String, Map<String, int>> playerStats = {};
                if (statsSnapshot.hasData) {
                  for (var doc in statsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    playerStats[data['playerId']] = {
                      'points': data['points'] ?? 0,
                      'fouls': data['fouls'] ?? 0,
                    };
                  }
                }
                
                final players = playerSnapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stats = playerStats[doc.id] ?? {'points': 0, 'fouls': 0};
                  return {
                    'id': doc.id,
                    'name': data['name'],
                    'number': data['number'],
                    'points': stats['points'],
                    'fouls': stats['fouls'],
                  };
                }).toList();
                
                return Column(
                  children: players.map((player) {
                    final color = title == 'Home Team' ? AppTheme.homeTeam : AppTheme.awayTeam;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppTheme.cardDark,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.2),
                          child: Text(
                            player['number'].toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                        title: Text(
                          player['name'],
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${player['points']} pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentGold,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                );
              },
            );
          },
        ),
      ],
    );
  }
}