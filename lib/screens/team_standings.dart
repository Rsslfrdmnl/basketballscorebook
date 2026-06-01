import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class TeamStandings extends StatefulWidget {
  const TeamStandings({super.key});

  @override
  State<TeamStandings> createState() => _TeamStandingsState();
}

class _TeamStandingsState extends State<TeamStandings> {
  String selectedDivision = '14U';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Standings'),
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
            .where('status', isEqualTo: 'completed')
            .where('division', isEqualTo: selectedDivision)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading standings'));
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
                      Icons.leaderboard,
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
            final division = data['division'] ?? '14U';

            if (!standings.containsKey(homeTeamId)) {
              standings[homeTeamId] = {
                'name': homeTeam,
                'id': homeTeamId,
                'wins': 0,
                'losses': 0,
                'pointsScored': 0,
                'pointsAllowed': 0,
                'gamesPlayed': 0,
                'division': division,
              };
            }
            if (!standings.containsKey(awayTeamId)) {
              standings[awayTeamId] = {
                'name': awayTeam,
                'id': awayTeamId,
                'wins': 0,
                'losses': 0,
                'pointsScored': 0,
                'pointsAllowed': 0,
                'gamesPlayed': 0,
                'division': division,
              };
            }

            if (homeScore > awayScore) {
              standings[homeTeamId]!['wins'] = (standings[homeTeamId]!['wins'] as num) + 1;
              standings[awayTeamId]!['losses'] = (standings[awayTeamId]!['losses'] as num) + 1;
            } else if (awayScore > homeScore) {
              standings[awayTeamId]!['wins'] = (standings[awayTeamId]!['wins'] as num) + 1;
              standings[homeTeamId]!['losses'] = (standings[homeTeamId]!['losses'] as num) + 1;
            } else {
              standings[homeTeamId]!['wins'] = (standings[homeTeamId]!['wins'] as num) + 0.5;
              standings[homeTeamId]!['losses'] = (standings[homeTeamId]!['losses'] as num) + 0.5;
              standings[awayTeamId]!['wins'] = (standings[awayTeamId]!['wins'] as num) + 0.5;
              standings[awayTeamId]!['losses'] = (standings[awayTeamId]!['losses'] as num) + 0.5;
            }

            standings[homeTeamId]!['pointsScored'] = (standings[homeTeamId]!['pointsScored'] as int) + homeScore;
            standings[homeTeamId]!['pointsAllowed'] = (standings[homeTeamId]!['pointsAllowed'] as int) + awayScore;
            standings[awayTeamId]!['pointsScored'] = (standings[awayTeamId]!['pointsScored'] as int) + awayScore;
            standings[awayTeamId]!['pointsAllowed'] = (standings[awayTeamId]!['pointsAllowed'] as int) + homeScore;
            
            standings[homeTeamId]!['gamesPlayed'] = (standings[homeTeamId]!['gamesPlayed'] as int) + 1;
            standings[awayTeamId]!['gamesPlayed'] = (standings[awayTeamId]!['gamesPlayed'] as int) + 1;
          }

          var sortedList = standings.values.toList();
          sortedList.sort((a, b) {
            if (b['wins'] != a['wins']) {
              return (b['wins'] as num).compareTo(a['wins'] as num);
            }
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

              String winsDisplay = wins % 1 == 0 ? wins.toInt().toString() : wins.toString();
              String lossesDisplay = losses % 1 == 0 ? losses.toInt().toString() : losses.toString();

              Color rankColor;
              IconData rankIcon;
              if (rank == 1) {
                rankColor = Colors.amber;
                rankIcon = Icons.star;
              } else if (rank == 2) {
                rankColor = Colors.grey;
                rankIcon = Icons.emoji_events;
              } else if (rank == 3) {
                rankColor = Colors.brown;
                rankIcon = Icons.emoji_events;
              } else {
                rankColor = Colors.grey[700]!;
                rankIcon = Icons.circle;
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.cardDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: rank == 1 
                      ? Colors.amber.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                    width: rank == 1 ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Rank
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: rankColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: rankColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: rank <= 3 
                            ? Icon(rankIcon, color: rankColor, size: 24)
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
                          borderRadius: BorderRadius.circular(8),
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