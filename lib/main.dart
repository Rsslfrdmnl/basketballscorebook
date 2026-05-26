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
import 'theme/app_theme.dart';
import 'widgets/team_selection_dialog.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
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

  @override
  void initState() {
    super.initState();
    _checkUserRole();
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
          isLoading = false;
        });
      } else {
        setState(() {
          isAdmin = false;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryDark,
              AppTheme.secondaryDark,
              AppTheme.surfaceDark,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Role badge
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
                
                // Logo
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
                
                // Manage Teams - Admin only
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

// Start Game - Both roles
_buildMenuButton(
  context,
  icon: Icons.play_arrow,
  label: 'Start Game',
  color: AppTheme.accentGreen,
  onTap: () => _startGame(context),
),

// Game History - Both roles
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

// MVP Leaderboard - Both roles
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

// Team Standings - Both roles
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
    );
  }

  Widget _buildMenuButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
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

  void _startGame(BuildContext context) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .get();
    
    if (snapshot.docs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 teams to start a game!'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => TeamSelectionDialog(
        teams: snapshot.docs,
        onTeamsSelected: (homeTeam, awayTeam) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScorebookScreen(
                homeTeamId: homeTeam.id,
                awayTeamId: awayTeam.id,
                homeTeamName: homeTeam['name'],
                awayTeamName: awayTeam['name'],
              ),
            ),
          );
        },
      ),
    );
  }
}