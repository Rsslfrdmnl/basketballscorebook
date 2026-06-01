import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class PlayerManagement extends StatefulWidget {
  final String teamId;
  final String teamName;

  const PlayerManagement({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<PlayerManagement> createState() => _PlayerManagementState();
}

class _PlayerManagementState extends State<PlayerManagement> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editNumberController = TextEditingController();
  
  String? _editingPlayerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Players - ${widget.teamName}'),
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Player Section - Premium styled
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Player Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: _numberController,
                          decoration: const InputDecoration(
                            labelText: 'No.',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addPlayer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: AppTheme.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // List of Players
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('teams')
                    .doc(widget.teamId)
                    .collection('players')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
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
                              Icons.people_outline,
                              size: 48,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No players added yet',
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
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final player = snapshot.data!.docs[index];
                      final bool isEditing = _editingPlayerId == player.id;
                      
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
                            ? _buildEditPlayerCard(player)
                            : _buildPlayerCard(player),
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

  Widget _buildPlayerCard(QueryDocumentSnapshot player) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.accentBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.accentBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            player['number'].toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.accentBlue,
            ),
          ),
        ),
      ),
      title: Text(
        player['name'],
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        'Jersey #${player['number']}',
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
                _editingPlayerId = player.id;
                _editNameController.text = player['name'];
                _editNumberController.text = player['number'].toString();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deletePlayer(player.id),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPlayerCard(QueryDocumentSnapshot player) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _editNameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _editNumberController,
                  decoration: const InputDecoration(
                    labelText: 'No.',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check, color: AppTheme.accentGreen),
                onPressed: () => _updatePlayer(player.id),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.accentRed),
                onPressed: () {
                  setState(() {
                    _editingPlayerId = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addPlayer() async {
    if (_nameController.text.trim().isEmpty || _numberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('players')
        .add({
      'name': _nameController.text.trim(),
      'number': int.parse(_numberController.text.trim()),
    });

    _nameController.clear();
    _numberController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Player added successfully!')),
    );
  }

  void _updatePlayer(String playerId) async {
    if (_editNameController.text.trim().isEmpty || _editNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('players')
        .doc(playerId)
        .update({
      'name': _editNameController.text.trim(),
      'number': int.parse(_editNumberController.text.trim()),
    });

    setState(() {
      _editingPlayerId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Player updated successfully!')),
    );
  }

  void _deletePlayer(String playerId) async {
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Player?'),
        content: const Text('This will permanently delete the player.'),
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
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('players')
          .doc(playerId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player deleted')),
      );
    }
  }
}