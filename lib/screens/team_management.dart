import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_management.dart';
import '../theme/app_theme.dart';

class TeamManagement extends StatefulWidget {
  const TeamManagement({super.key});

  @override
  State<TeamManagement> createState() => _TeamManagementState();
}

class _TeamManagementState extends State<TeamManagement> {
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _editTeamNameController = TextEditingController();
  String _selectedDivision = '14U';
  String? _editingTeamId;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Team Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teamNameController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Team Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _createTeam,
                  child: const Text('Add Team'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Teams List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('teams')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // Filter teams by division manually (handles missing fields)
                  final allTeams = snapshot.data!.docs;
                  final filteredTeams = allTeams.where((team) {
                    final data = team.data() as Map<String, dynamic>;
                    String division = data['division'] ?? '14U'; // Default to 14U if missing
                    return division == _selectedDivision;
                  }).toList();
                  
                  if (filteredTeams.isEmpty) {
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
                              Icons.group_off,
                              size: 48,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No teams in ${_selectedDivision} division',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: filteredTeams.length,
                    itemBuilder: (context, index) {
                      final team = filteredTeams[index];
                      final bool isEditing = _editingTeamId == team.id;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppTheme.cardDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                        child: isEditing 
                            ? _buildEditTeamCard(team)
                            : _buildTeamCard(team),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(QueryDocumentSnapshot team) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _selectedDivision == '14U' 
            ? AppTheme.accentBlue.withOpacity(0.1)
            : AppTheme.accentGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedDivision == '14U' 
              ? AppTheme.accentBlue.withOpacity(0.2)
              : AppTheme.accentGreen.withOpacity(0.2),
          ),
        ),
        child: Icon(
          _selectedDivision == '14U' 
            ? Icons.child_care
            : Icons.people,
          color: _selectedDivision == '14U' 
            ? AppTheme.accentBlue
            : AppTheme.accentGreen,
          size: 20,
        ),
      ),
      title: Text(
        team['name'],
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        _selectedDivision == '14U' ? '14U Division' : '16U Division',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.accentBlue),
            onPressed: () {
              setState(() {
                _editingTeamId = team.id;
                _editTeamNameController.text = team['name'];
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.people, color: AppTheme.accentBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerManagement(
                    teamId: team.id, 
                    teamName: team['name'],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteTeam(team.id),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTeamCard(QueryDocumentSnapshot team) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editTeamNameController,
              decoration: const InputDecoration(
                labelText: 'Edit Team Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.accentGreen),
            onPressed: () => _updateTeam(team.id, _editTeamNameController.text.trim()),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.accentRed),
            onPressed: () {
              setState(() {
                _editingTeamId = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDivisionTab(String division, IconData icon, Color color) {
    final isSelected = _selectedDivision == division;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDivision = division;
            _editingTeamId = null; // Cancel editing when switching divisions
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

  void _createTeam() async {
    if (_teamNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team name')),
      );
      return;
    }
    
    await FirebaseFirestore.instance.collection('teams').add({
      'name': _teamNameController.text.trim(),
      'division': _selectedDivision,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    _teamNameController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Team created in ${_selectedDivision} division!')),
    );
  }

  void _updateTeam(String teamId, String newName) async {
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team name')),
      );
      return;
    }
    
    await FirebaseFirestore.instance.collection('teams').doc(teamId).update({
      'name': newName,
    });
    
    setState(() {
      _editingTeamId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Team updated successfully!')),
    );
  }

  void _deleteTeam(String teamId) async {
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team?'),
        content: const Text('This will permanently delete the team and all its players.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // Delete all players first
      final playersSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('players')
          .get();
      
      for (var doc in playersSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete the team
      await FirebaseFirestore.instance.collection('teams').doc(teamId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team and players deleted')),
      );
    }
  }
}