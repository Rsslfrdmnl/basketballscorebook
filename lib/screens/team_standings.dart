import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class TeamStandings extends StatelessWidget {
  const TeamStandings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Standings'),
        backgroundColor: const Color.fromARGB(255, 228, 148, 28),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('❌ TeamStandings ERROR: ${snapshot.error}');
            return const Center(child: Text('Error loading standings'));
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
                  Text('No completed games yet'),
                ],
              ),
            );
          }

          // Calculate standings
          Map<String, Map<String, dynamic>> standings = {};

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final homeTeam = data['homeTeam'] ?? 'Unknown';
            final awayTeam = data['awayTeam'] ?? 'Unknown';
            final homeScore = data['homeScore'] ?? 0;
            final awayScore = data['awayScore'] ?? 0;
            final homeTeamId = data['homeTeamId'] ?? '';
            final awayTeamId = data['awayTeamId'] ?? '';

            // Initialize teams if not exist
            if (!standings.containsKey(homeTeamId)) {
              standings[homeTeamId] = {
                'name': homeTeam,
                'id': homeTeamId,
                'wins': 0,  // Changed to num to support 0.5
                'losses': 0,  // Changed to num
                'pointsScored': 0,
                'pointsAllowed': 0,
                'gamesPlayed': 0,
              };
            }
            if (!standings.containsKey(awayTeamId)) {
              standings[awayTeamId] = {
                'name': awayTeam,
                'id': awayTeamId,
                'wins': 0,  // Changed to num
                'losses': 0,  // Changed to num
                'pointsScored': 0,
                'pointsAllowed': 0,
                'gamesPlayed': 0,
              };
            }

            // Update stats
            if (homeScore > awayScore) {
              // Home team wins
              standings[homeTeamId]!['wins'] = (standings[homeTeamId]!['wins'] as num) + 1;
              standings[awayTeamId]!['losses'] = (standings[awayTeamId]!['losses'] as num) + 1;
            } else if (awayScore > homeScore) {
              // Away team wins
              standings[awayTeamId]!['wins'] = (standings[awayTeamId]!['wins'] as num) + 1;
              standings[homeTeamId]!['losses'] = (standings[homeTeamId]!['losses'] as num) + 1;
            } else {
              // Tie - count as half win/half loss
              standings[homeTeamId]!['wins'] = (standings[homeTeamId]!['wins'] as num) + 0.5;
              standings[homeTeamId]!['losses'] = (standings[homeTeamId]!['losses'] as num) + 0.5;
              standings[awayTeamId]!['wins'] = (standings[awayTeamId]!['wins'] as num) + 0.5;
              standings[awayTeamId]!['losses'] = (standings[awayTeamId]!['losses'] as num) + 0.5;
            }

            // Points
            standings[homeTeamId]!['pointsScored'] = (standings[homeTeamId]!['pointsScored'] as int) + homeScore;
            standings[homeTeamId]!['pointsAllowed'] = (standings[homeTeamId]!['pointsAllowed'] as int) + awayScore;
            standings[awayTeamId]!['pointsScored'] = (standings[awayTeamId]!['pointsScored'] as int) + awayScore;
            standings[awayTeamId]!['pointsAllowed'] = (standings[awayTeamId]!['pointsAllowed'] as int) + homeScore;
            
            // Games played
            standings[homeTeamId]!['gamesPlayed'] = (standings[homeTeamId]!['gamesPlayed'] as int) + 1;
            standings[awayTeamId]!['gamesPlayed'] = (standings[awayTeamId]!['gamesPlayed'] as int) + 1;
          }

          // Convert to list and sort by wins (descending)
          var sortedList = standings.values.toList();
          sortedList.sort((a, b) {
            // Sort by wins first, then by win percentage if tied
            if (b['wins'] != a['wins']) {
              return (b['wins'] as num).compareTo(a['wins'] as num);
            }
            // If wins are tied, sort by points scored
            return (b['pointsScored'] as int).compareTo(a['pointsScored'] as int);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sortedList.length,
            itemBuilder: (context, index) {
              final team = sortedList[index];
              final rank = index + 1;
              final gamesPlayed = team['gamesPlayed'] as int;
              final wins = team['wins'] as num;
              final losses = team['losses'] as num;
              final winPercentage = gamesPlayed > 0 ? (wins / gamesPlayed) * 100 : 0;
              final pointsScored = team['pointsScored'] as int;
              final pointsAllowed = team['pointsAllowed'] as int;
              final pointDiff = pointsScored - pointsAllowed;

              // Format wins/losses to show .5 for ties
              String winsDisplay = wins % 1 == 0 ? wins.toInt().toString() : wins.toString();
              String lossesDisplay = losses % 1 == 0 ? losses.toInt().toString() : losses.toString();

              // Medal colors for top 3
              Color rankColor;
              IconData rankIcon;
              if (rank == 1) {
                rankColor = Colors.amber;
                rankIcon = Icons.star;
              } else if (rank == 2) {
                rankColor = Colors.grey;
                rankIcon = Icons.star_half;
              } else if (rank == 3) {
                rankColor = Colors.brown;
                rankIcon = Icons.star_border;
              } else {
                rankColor = Colors.grey[700]!;
                rankIcon = Icons.circle;
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.cardDark,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Rank
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: rankColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: rankColor.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: rank <= 3 
                            ? Icon(rankIcon, color: rankColor, size: 20)
                            : Text(
                                rank.toString(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: rankColor,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Team info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '${gamesPlayed} games',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$winsDisplay - $lossesDisplay',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${winPercentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Point differential
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: pointDiff >= 0 
                            ? AppTheme.accentGreen.withOpacity(0.15) 
                            : AppTheme.accentRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: pointDiff >= 0 
                              ? AppTheme.accentGreen.withOpacity(0.3) 
                              : AppTheme.accentRed.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          pointDiff >= 0 ? '+$pointDiff' : '$pointDiff',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: pointDiff >= 0 
                              ? AppTheme.accentGreen 
                              : AppTheme.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}