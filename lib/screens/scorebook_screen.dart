import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../services/active_game_service.dart';

class ScorebookScreen extends StatefulWidget {
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final String gameId;

  const ScorebookScreen({
    super.key,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.gameId,
  });

  @override
  State<ScorebookScreen> createState() => _ScorebookScreenState();
}

class _ScorebookScreenState extends State<ScorebookScreen> {
  int homeScore = 0;
  int awayScore = 0;
  int homeTimeouts = 1;
  int awayTimeouts = 1;
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
  
  bool _isNavigatingBack = false;
  bool _isLoading = true;
  bool _isOffline = false;
  bool _hasPendingWrites = false;
  bool _isSubstituting = false;
  StreamSubscription<DocumentSnapshot>? _connectionSubscription;

  bool _showFoulWarning = false;
  String? _foulWarningPlayerName;
  int? _fouledOutPlayerId;
  bool _showBonusAlert = false;
  bool _homeInBonus = false;
  bool _awayInBonus = false;


  @override
  void initState() {
    super.initState();
    _loadGameData();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _checkFoulStatus(String playerId, String playerName, int fouls, bool isHome) {
  // Check for foul trouble (4 fouls)
  if (fouls == 4 && !_showFoulWarning) {
    setState(() {
      _showFoulWarning = true;
      _foulWarningPlayerName = playerName;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ FOUL TROUBLE: $playerName has 4 fouls!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.accentGold,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {
            setState(() => _showFoulWarning = false);
          },
        ),
      ),
    );
  }
  
  // Check for fouled out (5 fouls)
  if (fouls >= 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '❌ FOULED OUT: $playerName ($fouls fouls) - Must be substituted!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.accentRed,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'SUB NOW',
          onPressed: () {
            // Auto-open substitution mode
            setState(() {
              showSubstitutionMode = true;
              selectedSubstitutionPlayer = playerId;
            });
          },
        ),
      ),
    );
  }
  
  // Check for team bonus (7+ team fouls per quarter)
  _checkTeamBonus(isHome);
}

void _checkTeamBonus(bool isHome) {
  final teamFouls = isHome ? homeTeamFouls : awayTeamFouls;
  final wasInBonus = isHome ? _homeInBonus : _awayInBonus;
  final isInBonus = teamFouls >= 5;
  
  if (isInBonus && !wasInBonus) {
    if (isHome) {
      setState(() => _homeInBonus = true);
    } else {
      setState(() => _awayInBonus = true);
    }
  }
}

  void _checkConnectivity() {
    _connectionSubscription = FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .snapshots()
        .listen((event) {
      if (_isOffline && mounted) {
        setState(() => _isOffline = false);
        _showOnlineSnackbar();
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isOffline = true);
      }
    });
  }

  void _showOnlineSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Connection restored - Syncing data...'),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showOfflineSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text('Offline Mode - Data will sync when connection returns'),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentGold,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveDataWithOfflineSupport({
    required String path,
    required Map<String, dynamic> data,
    bool isUpdate = false,
    String? documentId,
  }) async {
    try {
      if (isUpdate && documentId != null) {
        await FirebaseFirestore.instance
            .collection(path)
            .doc(documentId)
            .update(data);
      } else if (documentId != null) {
        await FirebaseFirestore.instance
            .collection(path)
            .doc(documentId)
            .set(data);
      } else {
        await FirebaseFirestore.instance.collection(path).add(data);
      }
      
      if (_isOffline && mounted) {
        setState(() => _isOffline = false);
      }
    } catch (e) {
      if (!_isOffline && mounted) {
        setState(() => _isOffline = true);
        _showOfflineSnackbar();
      }
    }
  }

  Future<void> _loadGameData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .get();

      if (gameDoc.exists) {
        final data = gameDoc.data() as Map<String, dynamic>;
        setState(() {
          homeScore = data['homeScore'] ?? 0;
          awayScore = data['awayScore'] ?? 0;
          quarter = data['quarter'] ?? 1;
          
          if (quarter <= 2) {
            homeTimeouts = data['homeTimeouts'] ?? 1;
            awayTimeouts = data['awayTimeouts'] ?? 1;
          } else if (quarter <= 4) {
            homeTimeouts = data['homeTimeouts'] ?? 2;
            awayTimeouts = data['awayTimeouts'] ?? 2;
          } else {
            homeTimeouts = data['homeTimeouts'] ?? 1;
            awayTimeouts = data['awayTimeouts'] ?? 1;
          }
          
          homeTeamFouls = data['homeTeamFouls'] ?? 0;
          awayTeamFouls = data['awayTeamFouls'] ?? 0;

            _homeInBonus = homeTeamFouls >= 5;
            _awayInBonus = awayTeamFouls >= 5;
        });
      }

      final statsSnapshot = await FirebaseFirestore.instance
          .collection('player_stats')
          .where('gameId', isEqualTo: widget.gameId)
          .get();

      for (var doc in statsSnapshot.docs) {
        final stat = doc.data();
        final playerId = stat['playerId'];
        final teamId = stat['teamId'];
        final fouls = stat['fouls'] ?? 0;
        final q1 = stat['quarter1'] ?? 0;
        final q2 = stat['quarter2'] ?? 0;
        final q3 = stat['quarter3'] ?? 0;
        final q4 = stat['quarter4'] ?? 0;

        setState(() {
          playerFouls[playerId] = fouls;
          
          if (teamId == widget.homeTeamId) {
            if (q1 > 0) homePoints1Q[playerId] = q1;
            if (q2 > 0) homePoints2Q[playerId] = q2;
            if (q3 > 0) homePoints3Q[playerId] = q3;
            if (q4 > 0) homePoints4Q[playerId] = q4;
          } else {
            if (q1 > 0) awayPoints1Q[playerId] = q1;
            if (q2 > 0) awayPoints2Q[playerId] = q2;
            if (q3 > 0) awayPoints3Q[playerId] = q3;
            if (q4 > 0) awayPoints4Q[playerId] = q4;
          }
        });
      }

    } catch (e) {
      setState(() => _isOffline = true);
    }
    
    await _initializeActivePlayers();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _handleBackNavigation(BuildContext context) async {
    if (_isNavigatingBack) return;
    _isNavigatingBack = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Terminate Match?',
          style: TextStyle(color: AppTheme.accentGold),
        ),
        content: const Text(
          'Are you sure you want to terminate this match?\n\nAll game data will be deleted.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentBlue,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Terminate Match'),
          ),
        ],
      ),
    );

    _isNavigatingBack = false;

    if (confirmed == true) {
      await _deleteGameData();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ScorebookHome()),
        );
      }
    }
  }

  Future<void> _deleteGameData() async {
    await FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .delete();
    
    final statsSnapshot = await FirebaseFirestore.instance
        .collection('player_stats')
        .where('gameId', isEqualTo: widget.gameId)
        .get();
    
    for (var doc in statsSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  Widget _buildLandscapeLayout() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Row(
      children: [
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
              _buildCenterButton(
                icon: Icons.stop,
                color: AppTheme.accentRed,
                onTap: _endGame,
              ),
            ],
          ),
        ),
        
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
    
    return WillPopScope(
      onWillPop: () async {
        _handleBackNavigation(context);
        return false;
      },
      child: Scaffold(
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
        body: Column(
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.accentGold.withOpacity(0.9),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Offline Mode - Changes will sync when connection returns',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
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
    final size = isLandscape ? 36.0 : 32.0;
    
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

              if ((isHome && _homeInBonus) || (!isHome && _awayInBonus))
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.accentBlue.withOpacity(0.2),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppTheme.accentBlue),
    ),
    child: const Text(
      'PENALTY',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppTheme.accentBlue,
      ),
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
                  for (int i = 0; i < (quarter <= 2 ? 1 : 2); i++)
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
                  
                  return Container(
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
                          
                          GestureDetector(
                            onTap: () {
                              _toggleSubstitution(playerId, isHome);
                            },
                            child: Container(
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
                          ),
                          
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
                  );
                },
              );
            },
          ),
        ),
        
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
                      onPressed: () async {
                        setState(() {
                          if (isHome && homeTimeouts > 0) {
                            homeTimeouts--;
                          } else if (!isHome && awayTimeouts > 0) {
                            awayTimeouts--;
                          }
                        });
                        await _updateGameData();
                        await _saveActivePlayersToFirestore();
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

  List<QueryDocumentSnapshot> _sortPlayersByStatus(List<QueryDocumentSnapshot> players, bool isHome) {
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
    
    sortedPlayers.sort((a, b) {
      if (a['isActive'] && !b['isActive']) return -1;
      if (!a['isActive'] && b['isActive']) return 1;
      return 0;
    });
    
    return sortedPlayers.map((item) => item['doc'] as QueryDocumentSnapshot).toList();
  }

  Future<void> _initializeActivePlayers() async {
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
    
    final gameDoc = await FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .get();
    
    List<String> homePlayerIds = homeSnapshot.docs.map((doc) => doc.id).toList();
    List<String> awayPlayerIds = awaySnapshot.docs.map((doc) => doc.id).toList();
    
    Set<String> savedHomeActive = {};
    Set<String> savedAwayActive = {};
    
    if (gameDoc.exists && gameDoc.data() != null) {
      final data = gameDoc.data() as Map<String, dynamic>;
      if (data['activeHomePlayers'] != null) {
        savedHomeActive = Set<String>.from(List<String>.from(data['activeHomePlayers']));
      }
      if (data['activeAwayPlayers'] != null) {
        savedAwayActive = Set<String>.from(List<String>.from(data['activeAwayPlayers']));
      }
    }
    
    setState(() {
      if (savedHomeActive.isNotEmpty) {
        activeHomePlayers = savedHomeActive;
      } else {
        activeHomePlayers = Set.from(homePlayerIds.take(5));
      }
      
      if (savedAwayActive.isNotEmpty) {
        activeAwayPlayers = savedAwayActive;
      } else {
        activeAwayPlayers = Set.from(awayPlayerIds.take(5));
      }
    });
  }

  Future<void> _saveActivePlayersToFirestore() async {
    await _saveDataWithOfflineSupport(
      path: 'games',
      data: {
        'activeHomePlayers': activeHomePlayers.toList(),
        'activeAwayPlayers': activeAwayPlayers.toList(),
      },
      isUpdate: true,
      documentId: widget.gameId,
    );
  }

  Future<void> _updateGameData() async {
    await _saveDataWithOfflineSupport(
      path: 'games',
      data: {
        'homeScore': homeScore,
        'awayScore': awayScore,
        'quarter': quarter,
        'homeTimeouts': homeTimeouts,
        'awayTimeouts': awayTimeouts,
        'homeTeamFouls': homeTeamFouls,
        'awayTeamFouls': awayTeamFouls,
      },
      isUpdate: true,
      documentId: widget.gameId,
    );
  }

  Future<void> _toggleSubstitution(String playerId, bool isHome) async {
    if (_isSubstituting) return;
    
    setState(() {
      _isSubstituting = true;
    });
    
    try {
      setState(() {
        if (isHome) {
          if (activeHomePlayers.contains(playerId)) {
            activeHomePlayers.remove(playerId);
          } else {
            if (activeHomePlayers.length < 5) {
              activeHomePlayers.add(playerId);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ 5 players already on court! Sub out someone first.'),
                  backgroundColor: AppTheme.accentGold,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
          }
        } else {
          if (activeAwayPlayers.contains(playerId)) {
            activeAwayPlayers.remove(playerId);
          } else {
            if (activeAwayPlayers.length < 5) {
              activeAwayPlayers.add(playerId);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ 5 players already on court! Sub out someone first.'),
                  backgroundColor: AppTheme.accentGold,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
          }
        }
      });
      
      await _saveActivePlayersToFirestore();
    } finally {
      if (mounted) {
        setState(() {
          _isSubstituting = false;
        });
      }
    }
  }

  Future<void> _addScore(String playerId, int points, bool isHome) async {
    final isActive = isHome 
      ? activeHomePlayers.contains(playerId) 
      : activeAwayPlayers.contains(playerId);
    
    if (!isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Player is on bench! Click IN to substitute them.'),
          backgroundColor: AppTheme.accentPurple,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      if (isHome) {
        switch (quarter) {
          case 1: homePoints1Q[playerId] = (homePoints1Q[playerId] ?? 0) + points; break;
          case 2: homePoints2Q[playerId] = (homePoints2Q[playerId] ?? 0) + points; break;
          case 3: homePoints3Q[playerId] = (homePoints3Q[playerId] ?? 0) + points; break;
          case 4: homePoints4Q[playerId] = (homePoints4Q[playerId] ?? 0) + points; break;
          case 5: case 6: case 7: case 8:
            homePoints4Q[playerId] = (homePoints4Q[playerId] ?? 0) + points; break;
        }
        homeScore += points;
      } else {
        switch (quarter) {
          case 1: awayPoints1Q[playerId] = (awayPoints1Q[playerId] ?? 0) + points; break;
          case 2: awayPoints2Q[playerId] = (awayPoints2Q[playerId] ?? 0) + points; break;
          case 3: awayPoints3Q[playerId] = (awayPoints3Q[playerId] ?? 0) + points; break;
          case 4: awayPoints4Q[playerId] = (awayPoints4Q[playerId] ?? 0) + points; break;
          case 5: case 6: case 7: case 8:
            awayPoints4Q[playerId] = (awayPoints4Q[playerId] ?? 0) + points; break;
        }
        awayScore += points;
      }
    });
    
    await _savePlayerStatsInRealTime(playerId, points, isHome);
    await _updateGameData();
  }

  Future<void> _savePlayerStatsInRealTime(String playerId, int points, bool isHome) async {
    if (widget.gameId.isEmpty) return;
    
    final teamId = isHome ? widget.homeTeamId : widget.awayTeamId;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('player_stats')
          .where('gameId', isEqualTo: widget.gameId)
          .where('playerId', isEqualTo: playerId)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final currentPoints = doc['points'] ?? 0;
        final currentQ1 = doc['quarter1'] ?? 0;
        final currentQ2 = doc['quarter2'] ?? 0;
        final currentQ3 = doc['quarter3'] ?? 0;
        final currentQ4 = doc['quarter4'] ?? 0;
        
        Map<String, dynamic> updateData = {
          'points': currentPoints + points,
        };
        
        if (quarter == 1) updateData['quarter1'] = currentQ1 + points;
        else if (quarter == 2) updateData['quarter2'] = currentQ2 + points;
        else if (quarter == 3) updateData['quarter3'] = currentQ3 + points;
        else if (quarter >= 4) updateData['quarter4'] = currentQ4 + points;
        
        await _saveDataWithOfflineSupport(
          path: 'player_stats',
          data: updateData,
          isUpdate: true,
          documentId: doc.id,
        );
      } else {
        await _saveDataWithOfflineSupport(
          path: 'player_stats',
          data: {
            'gameId': widget.gameId,
            'teamId': teamId,
            'playerId': playerId,
            'points': points,
            'fouls': 0,
            'quarter1': quarter == 1 ? points : 0,
            'quarter2': quarter == 2 ? points : 0,
            'quarter3': quarter == 3 ? points : 0,
            'quarter4': quarter >= 4 ? points : 0,
            'isOvertime': quarter >= 5,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving player stats'),
            backgroundColor: AppTheme.accentRed,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleFoul(String playerId, bool isFoul, bool isHome) async {
  // Get player name for alerts
  String playerName = '';
  final playerDoc = await FirebaseFirestore.instance
      .collection('teams')
      .doc(isHome ? widget.homeTeamId : widget.awayTeamId)
      .collection('players')
      .doc(playerId)
      .get();
  if (playerDoc.exists) {
    playerName = playerDoc['name'];
  }
  
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
  
  // Check foul status after update
  final newFouls = playerFouls[playerId] ?? 0;
  _checkFoulStatus(playerId, playerName, newFouls, isHome);
  
  await _saveFoulInRealTime(playerId, isFoul, isHome);
  await _updateGameData();
}

  Future<void> _saveFoulInRealTime(String playerId, bool isFoul, bool isHome) async {
    if (widget.gameId.isEmpty) return;
    
    final teamId = isHome ? widget.homeTeamId : widget.awayTeamId;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('player_stats')
          .where('gameId', isEqualTo: widget.gameId)
          .where('playerId', isEqualTo: playerId)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final currentFouls = doc['fouls'] ?? 0;
        final newFouls = isFoul ? currentFouls - 1 : currentFouls + 1;
        await _saveDataWithOfflineSupport(
          path: 'player_stats',
          data: {'fouls': newFouls >= 0 ? newFouls : 0},
          isUpdate: true,
          documentId: doc.id,
        );
      } else {
        await _saveDataWithOfflineSupport(
          path: 'player_stats',
          data: {
            'gameId': widget.gameId,
            'teamId': teamId,
            'playerId': playerId,
            'points': 0,
            'fouls': 1,
            'quarter1': 0,
            'quarter2': 0,
            'quarter3': 0,
            'quarter4': 0,
            'isOvertime': quarter >= 5,
          },
        );
      }
    } catch (e) {
      // Silently handle error - offline mode will retry
    }
  }

  Future<void> _undoLastScore(String playerId, bool isHome) async {
    int currentPlayerPoints = 0;
    if (isHome) {
      switch (quarter) {
        case 1: currentPlayerPoints = homePoints1Q[playerId] ?? 0; break;
        case 2: currentPlayerPoints = homePoints2Q[playerId] ?? 0; break;
        case 3: currentPlayerPoints = homePoints3Q[playerId] ?? 0; break;
        case 4: currentPlayerPoints = homePoints4Q[playerId] ?? 0; break;
        default: currentPlayerPoints = homePoints4Q[playerId] ?? 0; break;
      }
    } else {
      switch (quarter) {
        case 1: currentPlayerPoints = awayPoints1Q[playerId] ?? 0; break;
        case 2: currentPlayerPoints = awayPoints2Q[playerId] ?? 0; break;
        case 3: currentPlayerPoints = awayPoints3Q[playerId] ?? 0; break;
        case 4: currentPlayerPoints = awayPoints4Q[playerId] ?? 0; break;
        default: currentPlayerPoints = awayPoints4Q[playerId] ?? 0; break;
      }
    }
    
    if (currentPlayerPoints < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot undo - player has no points in this quarter'),
          backgroundColor: AppTheme.accentGold,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if ((isHome && homeScore < 1) || (!isHome && awayScore < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot undo - team score is already 0'),
          backgroundColor: AppTheme.accentGold,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      int pointsToRemove = 1;
      if (isHome) {
        switch (quarter) {
          case 1: homePoints1Q[playerId] = (homePoints1Q[playerId] ?? 0) - pointsToRemove; break;
          case 2: homePoints2Q[playerId] = (homePoints2Q[playerId] ?? 0) - pointsToRemove; break;
          case 3: homePoints3Q[playerId] = (homePoints3Q[playerId] ?? 0) - pointsToRemove; break;
          case 4: homePoints4Q[playerId] = (homePoints4Q[playerId] ?? 0) - pointsToRemove; break;
        }
        homeScore -= pointsToRemove;
      } else {
        switch (quarter) {
          case 1: awayPoints1Q[playerId] = (awayPoints1Q[playerId] ?? 0) - pointsToRemove; break;
          case 2: awayPoints2Q[playerId] = (awayPoints2Q[playerId] ?? 0) - pointsToRemove; break;
          case 3: awayPoints3Q[playerId] = (awayPoints3Q[playerId] ?? 0) - pointsToRemove; break;
          case 4: awayPoints4Q[playerId] = (awayPoints4Q[playerId] ?? 0) - pointsToRemove; break;
        }
        awayScore -= pointsToRemove;
      }
    });
    
    await _updateStatsInRealTime(playerId, -1, isHome);
    await _updateGameData();
  }

  Future<void> _updateStatsInRealTime(String playerId, int pointsChange, bool isHome) async {
    if (widget.gameId.isEmpty) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('player_stats')
          .where('gameId', isEqualTo: widget.gameId)
          .where('playerId', isEqualTo: playerId)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final currentPoints = doc['points'] ?? 0;
        await _saveDataWithOfflineSupport(
          path: 'player_stats',
          data: {'points': currentPoints + pointsChange},
          isUpdate: true,
          documentId: doc.id,
        );
      }
    } catch (e) {
      // Silently handle error - offline mode will retry
    }
  }

  Future<void> _nextQuarter() async {
  if (quarter < 4) {
    setState(() {
      quarter++;
      if (quarter <= 2) {
        homeTimeouts = 1;
        awayTimeouts = 1;
      } else {
        homeTimeouts = 2;
        awayTimeouts = 2;
      }
      homeTeamFouls = 0;
      awayTeamFouls = 0;
      // RESET BONUS STATUS FOR NEW QUARTER
      _homeInBonus = false;
      _awayInBonus = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quarter $quarter started! Team fouls reset.'),
        backgroundColor: AppTheme.accentBlue,
      ),
    );
  } else if (quarter == 4 && homeScore == awayScore) {
    setState(() {
      quarter = 5;
      homeTimeouts = 1;
      awayTimeouts = 1;
      homeTeamFouls = 0;
      awayTeamFouls = 0;
      // RESET BONUS STATUS FOR OVERTIME
      _homeInBonus = false;
      _awayInBonus = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 OVERTIME! 🚨 Team fouls reset.'),
        backgroundColor: AppTheme.accentGold,
        duration: Duration(seconds: 3),
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
    setState(() {
      quarter++;
      homeTimeouts = 1;
      awayTimeouts = 1;
      homeTeamFouls = 0;
      awayTeamFouls = 0;
      // RESET BONUS STATUS FOR NEXT OVERTIME
      _homeInBonus = false;
      _awayInBonus = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OT #${quarter - 4} started! Team fouls reset.'),
        backgroundColor: AppTheme.accentGold,
      ),
    );
  }
  
  await _updateGameData();
}

  void _endGame() {
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
            onPressed: () async {
              Navigator.pop(context);
              
              await FirebaseFirestore.instance
                  .collection('games')
                  .doc(widget.gameId)
                  .update({
                'status': 'completed',
              });
              
              await _saveGameResults();
              
              if (mounted) {
                navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(builder: (context) => const ScorebookHome()),
                );
              }
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

  Future<void> _saveGameResults() async {
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
      
      final existingStats = await FirebaseFirestore.instance
          .collection('player_stats')
          .where('gameId', isEqualTo: widget.gameId)
          .where('playerId', isEqualTo: playerId)
          .get();
      
      if (existingStats.docs.isNotEmpty) {
        await existingStats.docs.first.reference.update({
          'points': totalPoints,
          'fouls': playerFouls[playerId] ?? 0,
          'quarter1': homePoints1Q[playerId] ?? 0,
          'quarter2': homePoints2Q[playerId] ?? 0,
          'quarter3': homePoints3Q[playerId] ?? 0,
          'quarter4': homePoints4Q[playerId] ?? 0,
        });
      } else {
        await FirebaseFirestore.instance.collection('player_stats').add({
          'gameId': widget.gameId,
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
      
      final existingStats = await FirebaseFirestore.instance
          .collection('player_stats')
          .where('gameId', isEqualTo: widget.gameId)
          .where('playerId', isEqualTo: playerId)
          .get();
      
      if (existingStats.docs.isNotEmpty) {
        await existingStats.docs.first.reference.update({
          'points': totalPoints,
          'fouls': playerFouls[playerId] ?? 0,
          'quarter1': awayPoints1Q[playerId] ?? 0,
          'quarter2': awayPoints2Q[playerId] ?? 0,
          'quarter3': awayPoints3Q[playerId] ?? 0,
          'quarter4': awayPoints4Q[playerId] ?? 0,
        });
      } else {
        await FirebaseFirestore.instance.collection('player_stats').add({
          'gameId': widget.gameId,
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
    }
  }
}