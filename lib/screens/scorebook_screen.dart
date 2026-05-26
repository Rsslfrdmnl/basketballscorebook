import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ScorebookScreen extends StatefulWidget {
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;

  const ScorebookScreen({
    super.key,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  @override
  State<ScorebookScreen> createState() => _ScorebookScreenState();
}

class _ScorebookScreenState extends State<ScorebookScreen> {
  int homeScore = 0;
  int awayScore = 0;
  int homeTimeouts = 2;
  int awayTimeouts = 2;
  int quarter = 1;
  int homeTeamFouls = 0;
  int awayTeamFouls = 0;
  
  Map<String, int> homePoints1Q = {};
  Map<String, int> homePoints2Q = {};
  Map<String, int> homePoints3Q = {};
  Map<String, int> homePoints4Q = {};
  
  Map<String, int> awayPoints1Q = {};
  Map<String, int> awayPoints2Q = {};
  Map<String, int> awayPoints3Q = {};
  Map<String, int> awayPoints4Q = {};
  
  Map<String, int> playerFouls = {};

  Set<String> activeHomePlayers = {};
  Set<String> activeAwayPlayers = {};
  bool showSubstitutionMode = false;
  String? selectedSubstitutionPlayer;
  
List<QueryDocumentSnapshot> _sortPlayersByStatus(List<QueryDocumentSnapshot> players, bool isHome) {
  // Create a list of players with their active status
  List<Map<String, dynamic>> sortedPlayers = players.map((player) {
    final playerId = player.id;
    final isActive = isHome 
      ? activeHomePlayers.contains(playerId) 
      : activeAwayPlayers.contains(playerId);
    return {
      'doc': player,
      'isActive': isActive,
    };
  }).toList();
  
  // Sort: active players first, then inactive
  sortedPlayers.sort((a, b) {
    if (a['isActive'] && !b['isActive']) return -1;
    if (!a['isActive'] && b['isActive']) return 1;
    return 0;
  });
  
  // Return only the documents
  return sortedPlayers.map((item) => item['doc'] as QueryDocumentSnapshot).toList();
}

  @override
  void initState() {
    super.initState();
    _initializeActivePlayers();
  }

  Widget _buildLandscapeLayout() {
  return Row(
    children: [
      // HOME TEAM SIDE
      Expanded(
        child: _buildTeamSide(
          teamId: widget.homeTeamId,
          teamName: widget.homeTeamName,
          isHome: true,
          score: homeScore,
          timeouts: homeTimeouts,
          points1Q: homePoints1Q,
          points2Q: homePoints2Q,
          points3Q: homePoints3Q,
          points4Q: homePoints4Q,
        ),
      ),
      
      // CENTER CONTROLS
      Container(
        width: 50,
        color: AppTheme.primaryDark,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: quarter >= 5 ? AppTheme.accentGold.withOpacity(0.5) : Colors.white10,
                ),
              ),
              child: Text(
                quarter >= 5 ? 'OT #${quarter - 4}' : 'Q$quarter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: quarter >= 5 ? AppTheme.accentGold : AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildCenterButton(
              icon: Icons.arrow_forward,
              color: AppTheme.accentBlue,
              onTap: _nextQuarter,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            _buildCenterButton(
              icon: Icons.stop,
              color: AppTheme.accentRed,
              onTap: _endGame,
            ),
          ],
        ),
      ),
      
      // AWAY TEAM SIDE
      Expanded(
        child: _buildTeamSide(
          teamId: widget.awayTeamId,
          teamName: widget.awayTeamName,
          isHome: false,
          score: awayScore,
          timeouts: awayTimeouts,
          points1Q: awayPoints1Q,
          points2Q: awayPoints2Q,
          points3Q: awayPoints3Q,
          points4Q: awayPoints4Q,
        ),
      ),
    ],
  );
}

  @override
Widget build(BuildContext context) {
  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  
  return Scaffold(
    appBar: AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: quarter >= 5 ? AppTheme.accentGold.withOpacity(0.5) : Colors.white10,
              ),
            ),
            child: Text(
              quarter >= 5 ? 'OT #${quarter - 4}' : 'Q$quarter',
              style: TextStyle(
                fontSize: isLandscape ? 14 : 12,
                fontWeight: FontWeight.w700,
                color: quarter >= 5 ? AppTheme.accentGold : AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
            ),
            child: Text(
              '$homeScore - $awayScore',
              style: TextStyle(
                fontSize: isLandscape ? 18 : 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.accentGold,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.primaryDark,
      elevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.homeTeamName,
                style: TextStyle(
                  fontSize: isLandscape ? 10 : 8,
                  color: AppTheme.homeTeam,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.awayTeamName,
                style: TextStyle(
                  fontSize: isLandscape ? 10 : 8,
                  color: AppTheme.awayTeam,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    body: isLandscape
      ? _buildLandscapeLayout()
      : _buildPortraitLayout(),
  );
}

// NEW: Portrait layout method
Widget _buildPortraitLayout() {
  return Column(
    children: [
      // Home team
      Expanded(
        child: _buildTeamSide(
          teamId: widget.homeTeamId,
          teamName: widget.homeTeamName,
          isHome: true,
          score: homeScore,
          timeouts: homeTimeouts,
          points1Q: homePoints1Q,
          points2Q: homePoints2Q,
          points3Q: homePoints3Q,
          points4Q: homePoints4Q,
        ),
      ),
      
      // Center controls (horizontal in portrait)
      Container(
        height: 50,
        color: AppTheme.primaryDark,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPortraitButton(
              icon: Icons.arrow_forward,
              color: AppTheme.accentBlue,
              label: 'Next',
              onTap: _nextQuarter,
            ),
            _buildPortraitButton(
              icon: Icons.swap_horiz,
              color: AppTheme.accentPurple,
              label: 'Sub',
              onTap: () {
                setState(() {
                  showSubstitutionMode = !showSubstitutionMode;
                });
              },
            ),
            _buildPortraitButton(
              icon: Icons.stop,
              color: AppTheme.accentRed,
              label: 'End',
              onTap: _endGame,
            ),
          ],
        ),
      ),
      
      // Away team
      Expanded(
        child: _buildTeamSide(
          teamId: widget.awayTeamId,
          teamName: widget.awayTeamName,
          isHome: false,
          score: awayScore,
          timeouts: awayTimeouts,
          points1Q: awayPoints1Q,
          points2Q: awayPoints2Q,
          points3Q: awayPoints3Q,
          points4Q: awayPoints4Q,
        ),
      ),
    ],
  );
}

// NEW: Portrait button helper
Widget _buildPortraitButton({
  required IconData icon,
  required Color color,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCenterButton({
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  final size = isLandscape ? 36.0 : 32.0; // Changed from int to double
  
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: IconButton(
      icon: Icon(icon, color: color, size: isLandscape ? 18 : 14),
      onPressed: onTap,
    ),
  );
}

  Widget _buildTeamSide({
    required String teamId,
    required String teamName,
    required bool isHome,
    required int score,
    required int timeouts,
    required Map<String, int> points1Q,
    required Map<String, int> points2Q,
    required Map<String, int> points3Q,
    required Map<String, int> points4Q,
  }) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isHome ? AppTheme.homeTeam.withOpacity(0.15) : AppTheme.awayTeam.withOpacity(0.15),
            border: Border(
              bottom: BorderSide(
                color: isHome ? AppTheme.homeTeam.withOpacity(0.3) : AppTheme.awayTeam.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isHome ? Icons.home : Icons.flight_takeoff,
                    color: isHome ? AppTheme.homeTeam : AppTheme.awayTeam,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    teamName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                score.toString(),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'TO',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  for (int i = 0; i < (quarter <= 2 ? 2 : 3); i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        i < timeouts ? Icons.timer : Icons.timer_off,
                        color: i < timeouts ? AppTheme.textPrimary : AppTheme.textMuted,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        
        // Players list
        Expanded(
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('players')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text(
            'Error loading players',
            style: TextStyle(color: AppTheme.accentRed),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.accentBlue),
        );
      }
      
      final players = snapshot.data!.docs;
      // Sort players: active first, then inactive
      final sortedPlayers = _sortPlayersByStatus(players, isHome);
      
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: sortedPlayers.length,
        itemBuilder: (context, index) {
          final player = sortedPlayers[index];
          final playerId = player.id;
          final playerName = player['name'];
          final playerNumber = player['number'];
          
          int totalPoints = (points1Q[playerId] ?? 0) + 
                           (points2Q[playerId] ?? 0) + 
                           (points3Q[playerId] ?? 0) + 
                           (points4Q[playerId] ?? 0);
          
          int fouls = playerFouls[playerId] ?? 0;
          
          final isActive = isHome 
            ? activeHomePlayers.contains(playerId) 
            : activeAwayPlayers.contains(playerId);
          
          return GestureDetector(
            onTap: () {
              _toggleSubstitution(playerId, isHome);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isActive 
                  ? AppTheme.accentGreen.withOpacity(0.15) 
                  : AppTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive 
                    ? AppTheme.accentGreen.withOpacity(0.5) 
                    : Colors.white10,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Player info
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isHome ? AppTheme.homeTeam.withOpacity(0.2) : AppTheme.awayTeam.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isHome ? AppTheme.homeTeam : AppTheme.awayTeam,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                playerNumber.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isHome ? AppTheme.homeTeam : AppTheme.awayTeam,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              playerName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Substitution indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.accentGreen.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isActive ? 'IN' : 'OUT',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppTheme.accentGreen : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    
                    // Fouls
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          return GestureDetector(
                            onTap: () => _toggleFoul(playerId, i < fouls, isHome),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Icon(
                                i < fouls ? Icons.circle : Icons.circle_outlined,
                                color: i < fouls ? AppTheme.accentRed : AppTheme.textMuted,
                                size: 12,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    
                    // Points
                    Container(
                      width: 28,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        totalPoints.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.accentGold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Scoring buttons
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _scoreBtn('1', () => _addScore(playerId, 1, isHome), AppTheme.accentGreen),
                          _scoreBtn('2', () => _addScore(playerId, 2, isHome), AppTheme.accentBlue),
                          _scoreBtn('3', () => _addScore(playerId, 3, isHome), AppTheme.accentPurple),
                          const SizedBox(width: 2),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.undo, color: AppTheme.textMuted, size: 14),
                              onPressed: () => _undoLastScore(playerId, isHome),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ),
),
        
        // Team fouls footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            border: Border(
              top: BorderSide(color: Colors.white10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (showSubstitutionMode) ...[
  Icon(
    Icons.people,
    size: 16,
    color: AppTheme.accentPurple,
  ),
  const SizedBox(width: 4),
  Text(
    '${isHome ? activeHomePlayers.length : activeAwayPlayers.length}/5 on court',
    style: const TextStyle(
      color: AppTheme.accentPurple,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  ),
  const SizedBox(width: 12),
],
                  const Text(
                    'Team Fouls: ',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isHome ? homeTeamFouls : awayTeamFouls}',
                      style: const TextStyle(
                        color: AppTheme.accentRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Timeout',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.pause, color: AppTheme.accentBlue, size: 18),
                      onPressed: () {
                        setState(() {
                          if (isHome && homeTimeouts > 0) {
                            homeTimeouts--;
                          } else if (!isHome && awayTimeouts > 0) {
                            awayTimeouts--;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreBtn(String label, VoidCallback onTap, Color color) {
  return Container(
    width: 26,
    height: 26,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ),
  );
}

  void _initializeActivePlayers() async {
  // Get all players for both teams
  final homeSnapshot = await FirebaseFirestore.instance
      .collection('teams')
      .doc(widget.homeTeamId)
      .collection('players')
      .get();
  
  final awaySnapshot = await FirebaseFirestore.instance
      .collection('teams')
      .doc(widget.awayTeamId)
      .collection('players')
      .get();
  
  setState(() {
    // Get all player IDs
    List<String> homePlayerIds = homeSnapshot.docs.map((doc) => doc.id).toList();
    List<String> awayPlayerIds = awaySnapshot.docs.map((doc) => doc.id).toList();
    
    // Take first 5 (or all if less than 5) - NO SHUFFLE
    activeHomePlayers = Set.from(homePlayerIds.take(5));
    activeAwayPlayers = Set.from(awayPlayerIds.take(5));
  });
}

  void _toggleSubstitution(String playerId, bool isHome) {
  setState(() {
    if (isHome) {
      if (activeHomePlayers.contains(playerId)) {
        // Sub OUT
        activeHomePlayers.remove(playerId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Player subbed out'),
            backgroundColor: AppTheme.accentBlue,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        // Sub IN
        if (activeHomePlayers.length < 5) {
          activeHomePlayers.add(playerId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Player subbed in'),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ 5 players already on court! Sub out someone first.'),
              backgroundColor: AppTheme.accentGold,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // Away team
      if (activeAwayPlayers.contains(playerId)) {
        activeAwayPlayers.remove(playerId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Player subbed out'),
            backgroundColor: AppTheme.accentBlue,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        if (activeAwayPlayers.length < 5) {
          activeAwayPlayers.add(playerId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Player subbed in'),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ 5 players already on court! Sub out someone first.'),
              backgroundColor: AppTheme.accentGold,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  });
}

bool _isCourtFull(bool isHome) {
  return isHome ? activeHomePlayers.length >= 5 : activeAwayPlayers.length >= 5;
}

  void _addScore(String playerId, int points, bool isHome) {
    // Check if player is active (if substitution mode is on)
    if (showSubstitutionMode) {
      final isActive = isHome 
        ? activeHomePlayers.contains(playerId) 
        : activeAwayPlayers.contains(playerId);
      if (!isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Player is on bench! Click to substitute them in.'),
            backgroundColor: AppTheme.accentPurple,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    
    setState(() {
      if (isHome) {
        switch (quarter) {
          case 1: homePoints1Q[playerId] = (homePoints1Q[playerId] ?? 0) + points; break;
          case 2: homePoints2Q[playerId] = (homePoints2Q[playerId] ?? 0) + points; break;
          case 3: homePoints3Q[playerId] = (homePoints3Q[playerId] ?? 0) + points; break;
          case 4: homePoints4Q[playerId] = (homePoints4Q[playerId] ?? 0) + points; break;
          case 5: // OT
          case 6:
          case 7:
          case 8:
            homePoints4Q[playerId] = (homePoints4Q[playerId] ?? 0) + points; break;
        }
        homeScore += points;
      } else {
        switch (quarter) {
          case 1: awayPoints1Q[playerId] = (awayPoints1Q[playerId] ?? 0) + points; break;
          case 2: awayPoints2Q[playerId] = (awayPoints2Q[playerId] ?? 0) + points; break;
          case 3: awayPoints3Q[playerId] = (awayPoints3Q[playerId] ?? 0) + points; break;
          case 4: awayPoints4Q[playerId] = (awayPoints4Q[playerId] ?? 0) + points; break;
          case 5: // OT
          case 6:
          case 7:
          case 8:
            awayPoints4Q[playerId] = (awayPoints4Q[playerId] ?? 0) + points; break;
        }
        awayScore += points;
      }
    });
  }

  void _toggleFoul(String playerId, bool isFoul, bool isHome) {
    setState(() {
      if (isFoul) {
        playerFouls[playerId] = (playerFouls[playerId] ?? 0) - 1;
        if (playerFouls[playerId] == 0) playerFouls.remove(playerId);
        if (isHome) homeTeamFouls--; else awayTeamFouls--;
      } else {
        playerFouls[playerId] = (playerFouls[playerId] ?? 0) + 1;
        if (isHome) homeTeamFouls++; else awayTeamFouls++;
      }
    });
  }

  void _undoLastScore(String playerId, bool isHome) {
    setState(() {
      int pointsToRemove = 1;
      if (isHome) {
        switch (quarter) {
          case 1: if ((homePoints1Q[playerId] ?? 0) >= pointsToRemove) homePoints1Q[playerId] = (homePoints1Q[playerId] ?? 0) - pointsToRemove; break;
          case 2: if ((homePoints2Q[playerId] ?? 0) >= pointsToRemove) homePoints2Q[playerId] = (homePoints2Q[playerId] ?? 0) - pointsToRemove; break;
          case 3: if ((homePoints3Q[playerId] ?? 0) >= pointsToRemove) homePoints3Q[playerId] = (homePoints3Q[playerId] ?? 0) - pointsToRemove; break;
          case 4: if ((homePoints4Q[playerId] ?? 0) >= pointsToRemove) homePoints4Q[playerId] = (homePoints4Q[playerId] ?? 0) - pointsToRemove; break;
        }
        homeScore -= pointsToRemove;
      } else {
        switch (quarter) {
          case 1: if ((awayPoints1Q[playerId] ?? 0) >= pointsToRemove) awayPoints1Q[playerId] = (awayPoints1Q[playerId] ?? 0) - pointsToRemove; break;
          case 2: if ((awayPoints2Q[playerId] ?? 0) >= pointsToRemove) awayPoints2Q[playerId] = (awayPoints2Q[playerId] ?? 0) - pointsToRemove; break;
          case 3: if ((awayPoints3Q[playerId] ?? 0) >= pointsToRemove) awayPoints3Q[playerId] = (awayPoints3Q[playerId] ?? 0) - pointsToRemove; break;
          case 4: if ((awayPoints4Q[playerId] ?? 0) >= pointsToRemove) awayPoints4Q[playerId] = (awayPoints4Q[playerId] ?? 0) - pointsToRemove; break;
        }
        awayScore -= pointsToRemove;
      }
    });
  }

  void _nextQuarter() {
    if (quarter < 4) {
      setState(() {
        quarter++;
        if (quarter <= 2) {
          homeTimeouts = 2;
          awayTimeouts = 2;
        } else {
          homeTimeouts = 3;
          awayTimeouts = 3;
        }
        homeTeamFouls = 0;
        awayTeamFouls = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quarter $quarter started!'),
          backgroundColor: AppTheme.accentBlue,
        ),
      );
    } else if (quarter == 4 && homeScore == awayScore) {
      // OT STARTS HERE
      setState(() {
        quarter = 5; // OT
        homeTimeouts = 1; // 1 timeout per OT
        awayTimeouts = 1;
        homeTeamFouls = 0;
        awayTeamFouls = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🚨 OVERTIME! 🚨'),
          backgroundColor: AppTheme.accentGold,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (quarter == 4 && homeScore != awayScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game is in 4th quarter!'),
          backgroundColor: AppTheme.accentGold,
        ),
      );
    } else if (quarter >= 5) {
      // Already in OT
      setState(() {
        quarter++;
        homeTimeouts = 1;
        awayTimeouts = 1;
        homeTeamFouls = 0;
        awayTeamFouls = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OT #${quarter - 4} started!'),
          backgroundColor: AppTheme.accentGold,
        ),
      );
    }
  }

  void _endGame() {
    // Don't allow ending if game is tied
    if (homeScore == awayScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot end game! Score is tied. Play overtime! 🚨'),
          backgroundColor: AppTheme.accentGold,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.homeTeamName} $homeScore - $awayScore ${widget.awayTeamName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (quarter >= 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'OT #${quarter - 4}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveGameResults();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            child: const Text('End Game'),
          ),
        ],
      ),
    );
  }

  void _saveGameResults() async {
    final gameRef = await FirebaseFirestore.instance.collection('games').add({
      'homeTeam': widget.homeTeamName,
      'awayTeam': widget.awayTeamName,
      'homeTeamId': widget.homeTeamId,
      'awayTeamId': widget.awayTeamId,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'quarter': quarter,
      'isOvertime': quarter >= 5,
      'overtimePeriods': quarter >= 5 ? quarter - 4 : 0,
      'date': DateTime.now(),
      'status': 'completed',
    });
    
    // Save player stats
    Set<String> homePlayers = {};
    homePlayers.addAll(homePoints1Q.keys);
    homePlayers.addAll(homePoints2Q.keys);
    homePlayers.addAll(homePoints3Q.keys);
    homePlayers.addAll(homePoints4Q.keys);
    
    for (var playerId in homePlayers) {
      int totalPoints = (homePoints1Q[playerId] ?? 0) + 
                       (homePoints2Q[playerId] ?? 0) + 
                       (homePoints3Q[playerId] ?? 0) + 
                       (homePoints4Q[playerId] ?? 0);
      await FirebaseFirestore.instance.collection('player_stats').add({
        'gameId': gameRef.id,
        'teamId': widget.homeTeamId,
        'playerId': playerId,
        'points': totalPoints,
        'fouls': playerFouls[playerId] ?? 0,
        'quarter1': homePoints1Q[playerId] ?? 0,
        'quarter2': homePoints2Q[playerId] ?? 0,
        'quarter3': homePoints3Q[playerId] ?? 0,
        'quarter4': homePoints4Q[playerId] ?? 0,
        'isOvertime': quarter >= 5,
      });
    }
    
    Set<String> awayPlayers = {};
    awayPlayers.addAll(awayPoints1Q.keys);
    awayPlayers.addAll(awayPoints2Q.keys);
    awayPlayers.addAll(awayPoints3Q.keys);
    awayPlayers.addAll(awayPoints4Q.keys);
    
    for (var playerId in awayPlayers) {
      int totalPoints = (awayPoints1Q[playerId] ?? 0) + 
                       (awayPoints2Q[playerId] ?? 0) + 
                       (awayPoints3Q[playerId] ?? 0) + 
                       (awayPoints4Q[playerId] ?? 0);
      await FirebaseFirestore.instance.collection('player_stats').add({
        'gameId': gameRef.id,
        'teamId': widget.awayTeamId,
        'playerId': playerId,
        'points': totalPoints,
        'fouls': playerFouls[playerId] ?? 0,
        'quarter1': awayPoints1Q[playerId] ?? 0,
        'quarter2': awayPoints2Q[playerId] ?? 0,
        'quarter3': awayPoints3Q[playerId] ?? 0,
        'quarter4': awayPoints4Q[playerId] ?? 0,
        'isOvertime': quarter >= 5,
      });
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Game saved successfully! 🏀'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }
}