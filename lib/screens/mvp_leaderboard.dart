import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MVPLeaderboard extends StatelessWidget {
  const MVPLeaderboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MVP Leaderboard'),
        backgroundColor: const Color.fromARGB(255, 228, 148, 28),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .where('status', isEqualTo: 'completed')
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
            return const Center(child: Text('No completed games yet'));
          }
          
          // Count MVP wins
          Map<String, Map<String, dynamic>> mvpCount = {};
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final mvpName = data['mvpName'];
            final mvpPoints = data['mvpPoints'] ?? 0;
            final mvpTeam = data['mvpTeam'] ?? 'Unknown';
            
            if (mvpName != null) {
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
          
          return ListView.builder(
            itemCount: sortedList.length,
            itemBuilder: (context, index) {
              final player = sortedList[index];
              final rank = index + 1;
              
              IconData medalIcon;
              Color medalColor;
              if (rank == 1) {
                medalIcon = Icons.star;
                medalColor = Colors.amber;
              } else if (rank == 2) {
                medalIcon = Icons.star_half;
                medalColor = Colors.grey;
              } else if (rank == 3) {
                medalIcon = Icons.star_border;
                medalColor = Colors.brown;
              } else {
                medalIcon = Icons.circle;
                medalColor = Colors.grey[300]!;
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: medalColor,
                    child: Icon(medalIcon, color: Colors.white),
                  ),
                  title: Text(
                    player['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(player['team']),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${player['mvpWins']} 🏆',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${player['totalPoints']} pts',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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