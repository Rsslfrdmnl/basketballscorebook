import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class TeamSelectionDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> teams;
  final Function(QueryDocumentSnapshot, QueryDocumentSnapshot) onTeamsSelected;

  const TeamSelectionDialog({
    super.key,
    required this.teams,
    required this.onTeamsSelected,
  });

  @override
  State<TeamSelectionDialog> createState() => _TeamSelectionDialogState();
}

class _TeamSelectionDialogState extends State<TeamSelectionDialog> {
  QueryDocumentSnapshot? homeTeam;
  QueryDocumentSnapshot? awayTeam;
  String selectedDivision = '14U';

  // Filter teams by division
  List<QueryDocumentSnapshot> get _filteredTeams {
    return widget.teams.where((team) {
      final data = team.data() as Map<String, dynamic>;
      String division = data['division'] ?? '14U';
      return division == selectedDivision;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: AppTheme.surfaceDark,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentGold.withOpacity(0.15),
                    AppTheme.accentGold.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accentGold.withOpacity(0.2),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_basketball,
                    size: 32,
                    color: AppTheme.accentGold,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Teams',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Choose division and match up',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Division Selector - Premium Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.secondaryDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDivisionOption('14U', AppTheme.accentBlue),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildDivisionOption('16U', AppTheme.accentGreen),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Home Team Selection
            _buildTeamDropdown(
              label: 'Home Team',
              value: homeTeam,
              icon: Icons.home,
              color: AppTheme.homeTeam,
              onChanged: (value) {
                setState(() {
                  homeTeam = value;
                  if (value == awayTeam) {
                    awayTeam = null;
                  }
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Away Team Selection
            _buildTeamDropdown(
              label: 'Away Team',
              value: awayTeam,
              icon: Icons.flight_takeoff,
              color: AppTheme.awayTeam,
              onChanged: (value) {
                setState(() {
                  awayTeam = value;
                  if (value == homeTeam) {
                    homeTeam = null;
                  }
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (homeTeam != null && awayTeam != null)
                        ? () {
                            Navigator.pop(context);
                            widget.onTeamsSelected(homeTeam!, awayTeam!);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Start Game',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivisionOption(String division, Color color) {
    final isSelected = selectedDivision == division;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDivision = division;
          homeTeam = null;
          awayTeam = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: isSelected ? color : AppTheme.textMuted,
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

  Widget _buildTeamDropdown({
    required String label,
    required QueryDocumentSnapshot? value,
    required IconData icon,
    required Color color,
    required Function(QueryDocumentSnapshot?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.secondaryDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value != null ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1),
              width: value != null ? 2 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<QueryDocumentSnapshot>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.surfaceDark,
              hint: Text(
                'Select $label',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              items: _filteredTeams.map((team) {
                return DropdownMenuItem(
                  value: team,
                  child: Text(
                    team['name'],
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              icon: Icon(Icons.arrow_drop_down, color: color),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}