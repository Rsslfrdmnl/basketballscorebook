import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/team_management.dart';
import 'screens/scorebook_screen.dart';
import 'screens/game_history.dart';
import 'screens/mvp_leaderboard.dart';
import 'screens/team_standings.dart';
import 'screens/live_game_viewer.dart';
import 'screens/public_home.dart';
import 'theme/app_theme.dart';
import 'widgets/team_selection_dialog.dart';
import 'services/active_game_service.dart';

// Global navigator key for safe navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable Firebase Auth persistence
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  
  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scorebook Pro',
      theme: AppTheme.darkTheme,
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Wrapper widget to handle auth state and redirect accordingly
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
          ),
        ),
      );
    }

    if (_currentUser != null) {
      return const ScorebookHome();
    } else {
      return const PublicHome();
    }
  }
}

class ScorebookHome extends StatefulWidget {
  const ScorebookHome({super.key});

  @override
  State<ScorebookHome> createState() => _ScorebookHomeState();
}

class _ScorebookHomeState extends State<ScorebookHome> {
  bool isAdmin = false;
  bool isLoading = true;
  String username = '';
  bool hasActiveGame = false;
  String? activeGameStarter;
  bool _isGameStarter = false;
  StreamSubscription? _activeGameSubscription;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _listenToActiveGame();
  }

  @override
  void dispose() {
    _activeGameSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          isAdmin = doc['role'] == 'admin';
          username = doc['username'] ?? 'User';
          isLoading = false;
        });
      } else {
        setState(() {
          isAdmin = false;
          username = 'User';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _listenToActiveGame() {
    _activeGameSubscription = ActiveGameService.listenToActiveGame().listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        final game = snapshot.docs.first;
        final data = game.data() as Map<String, dynamic>;
        setState(() {
          hasActiveGame = true;
          activeGameStarter = data['startedBy'] ?? 'Another admin';
        });
        _checkIfUserIsGameStarter();
      } else if (mounted) {
        setState(() {
          hasActiveGame = false;
          activeGameStarter = null;
          _isGameStarter = false;
        });
      }
    });
  }

  Future<void> _checkIfUserIsGameStarter() async {
    final isStarter = await ActiveGameService.isCurrentUserGameStarter();
    if (mounted) {
      setState(() {
        _isGameStarter = isStarter;
      });
    }
  }

  void _startGame() async {
    final hasActive = await ActiveGameService.hasActiveGame();
    
    if (hasActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ There is already an active game in progress!'),
            backgroundColor: AppTheme.accentRed,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .get();
    
    if (snapshot.docs.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Need at least 2 teams to start a game!'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return;
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TeamSelectionDialog(
        teams: snapshot.docs,
        onTeamsSelected: (homeTeam, awayTeam) async {
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          
          try {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) return;
            
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            final userDisplayName = userDoc['username'] ?? currentUser.email;
            final userRole = userDoc['role'] ?? 'sub_admin';
            
            final gameRef = await FirebaseFirestore.instance.collection('games').add({
              'homeTeam': homeTeam['name'],
              'awayTeam': awayTeam['name'],
              'homeTeamId': homeTeam.id,
              'awayTeamId': awayTeam.id,
              'homeScore': 0,
              'awayScore': 0,
              'quarter': 1,
              'division': homeTeam['division'] ?? '14U',
              'status': 'in_progress',
              'date': DateTime.now(),
              'startedBy': userDisplayName,
              'startedByUid': currentUser.uid,
              'startedByRole': userRole,
              'startedAt': FieldValue.serverTimestamp(),
            });
            
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScorebookScreen(
                    homeTeamId: homeTeam.id,
                    awayTeamId: awayTeam.id,
                    homeTeamName: homeTeam['name'],
                    awayTeamName: awayTeam['name'],
                    gameId: gameRef.id,
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: AppTheme.accentRed,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalye Oro Scorebook'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppTheme.accentBlue),
                const SizedBox(width: 4),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: AppTheme.accentGreen,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasActiveGame && !_isGameStarter) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.15),
                border: Border(
                  bottom: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.accentGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ Game in Progress',
                          style: TextStyle(
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Started by: $activeGameStarter',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LiveGameViewer(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                    ),
                    child: const Text('VIEW LIVE'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (hasActiveGame && _isGameStarter) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.15),
                border: Border(
                  bottom: BorderSide(color: AppTheme.accentGreen.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: AppTheme.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔄 Your Game is in Progress',
                          style: TextStyle(
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'Tap below to resume scoring',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final gameDetails = await ActiveGameService.getActiveGameDetails();
                      final activeGame = await ActiveGameService.getActiveGame();
                      if (gameDetails != null && activeGame != null && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScorebookScreen(
                              homeTeamId: gameDetails['homeTeamId'],
                              awayTeamId: gameDetails['awayTeamId'],
                              homeTeamName: gameDetails['homeTeam'],
                              awayTeamName: gameDetails['awayTeam'],
                              gameId: activeGame.id,
                            ),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentGreen,
                    ),
                    child: const Text('RESUME'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAdmin ? AppTheme.accentGold.withOpacity(0.2) : AppTheme.accentBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAdmin ? AppTheme.accentGold : AppTheme.accentBlue,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isAdmin ? '👑 ADMIN' : '👤 SUB ADMIN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAdmin ? AppTheme.accentGold : AppTheme.accentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: AppTheme.accentBlue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.sports_basketball,
                        size: 50,
                        color: AppTheme.accentGold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SCOREBOOK PRO',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: 3,
                      ),
                    ),
                    const Text(
                      'Digital Basketball Scorebook',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 50,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    if (isAdmin)
                      _buildMenuButton(
                        context,
                        icon: Icons.group_add,
                        label: 'Manage Teams',
                        color: AppTheme.accentBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TeamManagement(),
                            ),
                          );
                        },
                      ),

                    if (!hasActiveGame || (hasActiveGame && _isGameStarter))
                      _buildMenuButton(
                        context,
                        icon: Icons.play_arrow,
                        label: hasActiveGame && _isGameStarter ? 'Resume Game' : 'Start Game',
                        color: hasActiveGame && _isGameStarter ? AppTheme.accentGold : AppTheme.accentGreen,
                        onTap: hasActiveGame && _isGameStarter
                            ? () async {
                                final gameDetails = await ActiveGameService.getActiveGameDetails();
                                final activeGame = await ActiveGameService.getActiveGame();
                                if (gameDetails != null && activeGame != null && mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ScorebookScreen(
                                        homeTeamId: gameDetails['homeTeamId'],
                                        awayTeamId: gameDetails['awayTeamId'],
                                        homeTeamName: gameDetails['homeTeam'],
                                        awayTeamName: gameDetails['awayTeam'],
                                        gameId: activeGame.id,
                                      ),
                                    ),
                                  );
                                }
                              }
                            : _startGame,
                      ),

                    _buildMenuButton(
                      context,
                      icon: Icons.history,
                      label: 'Game History',
                      color: AppTheme.accentPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GameHistory(),
                          ),
                        );
                      },
                    ),

                    _buildMenuButton(
                      context,
                      icon: Icons.star,
                      label: 'MVP Leaderboard',
                      color: AppTheme.accentGold,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MVPLeaderboard(),
                          ),
                        );
                      },
                    ),

                    _buildMenuButton(
                      context,
                      icon: Icons.leaderboard,
                      label: 'Team Standings',
                      color: AppTheme.accentOrange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TeamStandings(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.3), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}