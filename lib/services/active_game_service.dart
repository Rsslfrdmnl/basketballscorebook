// lib/services/active_game_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveGameService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Check if there's an active game in progress
  static Future<bool> hasActiveGame() async {
    final snapshot = await _firestore
        .collection('games')
        .where('status', isEqualTo: 'in_progress')
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
  
  // Get the current active game
  static Future<DocumentSnapshot?> getActiveGame() async {
    final snapshot = await _firestore
        .collection('games')
        .where('status', isEqualTo: 'in_progress')
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }
  
  // Listen to active game status in real-time
  static Stream<QuerySnapshot> listenToActiveGame() {
    return _firestore
        .collection('games')
        .where('status', isEqualTo: 'in_progress')
        .limit(1)
        .snapshots();
  }
  
  // Get the admin who started the current game
  static Future<String?> getActiveGameStarter() async {
    final activeGame = await getActiveGame();
    if (activeGame != null && activeGame.exists) {
      final data = activeGame.data() as Map<String, dynamic>;
      return data['startedBy'];
    }
    return null;
  }
  
  // Get the UID of who started the current game
  static Future<String?> getActiveGameStarterUid() async {
    final activeGame = await getActiveGame();
    if (activeGame != null && activeGame.exists) {
      final data = activeGame.data() as Map<String, dynamic>;
      return data['startedByUid'];
    }
    return null;
  }
  
  // Check if current user is the one who started the active game
  static Future<bool> isCurrentUserGameStarter() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    
    final starterUid = await getActiveGameStarterUid();
    return starterUid == currentUser.uid;
  }
  
  // Get active game details
  static Future<Map<String, dynamic>?> getActiveGameDetails() async {
    final activeGame = await getActiveGame();
    if (activeGame != null && activeGame.exists) {
      return activeGame.data() as Map<String, dynamic>;
    }
    return null;
  }
}