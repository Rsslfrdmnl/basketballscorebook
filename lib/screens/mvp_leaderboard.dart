import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class MVPLeaderboard extends StatefulWidget {
  const MVPLeaderboard({super.key});

  @override
  State<MVPLeaderboard> createState() => _MVPLeaderboardState();
}

class _MVPLeaderboardState extends State<MVPLeaderboard> {
  String selectedDivision = '14U';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MVP Leaderboard'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Division Tabs - Premium Design
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
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
          
          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('games')
                  .where('status', isEqualTo: 'completed')
                  .where('division', isEqualTo: selectedDivision)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading data'));
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
                            Icons.info_outline,
                            size: 48,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No completed games in ${selectedDivision} division',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Games must be completed to appear on the leaderboard',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Count MVP wins
                Map<String, Map<String, dynamic>> mvpCount = {};
                
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final mvpName = data['mvpName'];
                  final mvpPoints = data['mvpPoints'] ?? 0;
                  final mvpTeam = data['mvpTeam'] ?? 'Unknown';
                  
                  if (mvpName != null && mvpName != 'No MVP') {
                    if (!mvpCount.containsKey(mvpName)) {
                      mvpCount[mvpName] = {
                        'name': mvpName,
                        'team': mvpTeam,
                        'mvpWins': 0,
                        'totalPoints': 0,
                      };
                    }
                    mvpCount[mvpName]!['mvpWins'] = (mvpCount[mvpName]!['mvpWins'] as int) + 1;
                    mvpCount[mvpName]!['totalPoints'] = (mvpCount[mvpName]!['totalPoints'] as int) + mvpPoints;
                  }
                }
                
                // Convert to list and sort by MVP wins
                var sortedList = mvpCount.values.toList();
                sortedList.sort((a, b) => (b['mvpWins'] as int).compareTo(a['mvpWins'] as int));
                
                if (sortedList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_border, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'No MVP data available yet',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sortedList.length,
                  itemBuilder: (context, index) {
                    final player = sortedList[index];
                    final rank = index + 1;
                    
                    // Medal styling
                    Color medalColor;
                    IconData medalIcon;
                    double medalSize;
                    String medalLabel;
                    
                    if (rank == 1) {
                      medalColor = Colors.amber;
                      medalIcon = Icons.star;
                      medalSize = 32;
                      medalLabel = '🥇';
                    } else if (rank == 2) {
                      medalColor = Colors.grey;
                      medalIcon = Icons.emoji_events;
                      medalSize = 28;
                      medalLabel = '🥈';
                    } else if (rank == 3) {
                      medalColor = Colors.brown;
                      medalIcon = Icons.emoji_events;
                      medalSize = 24;
                      medalLabel = '🥉';
                    } else {
                      medalColor = Colors.grey[700]!;
                      medalIcon = Icons.circle;
                      medalSize = 20;
                      medalLabel = rank.toString();
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
                            // Rank Medal
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: medalColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: medalColor.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  medalLabel,
                                  style: const TextStyle(
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Player info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    player['team'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Stats
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.emoji_events,
                                      size: 16,
                                      color: AppTheme.accentGold,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${player['mvpWins']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.accentGold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${player['totalPoints']} pts',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
              ? color.withOpacity(0.15)
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
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}