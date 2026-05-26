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

  @override
Widget build(BuildContext context) {
  return Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    backgroundColor: AppTheme.surfaceDark,
    insetPadding: const EdgeInsets.all(8),
    child: Container(
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.sports_basketball,
                size: 24,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Teams',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose home and away teams',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Home Team Selection - Compact
            _buildCompactDropdown(
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
            
            const SizedBox(height: 12),
            
            // Away Team Selection - Compact
            _buildCompactDropdown(
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
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 13,
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
    ),
  );
}

// Add this compact dropdown helper
Widget _buildCompactDropdown({
  required String label,
  required QueryDocumentSnapshot? value,
  required IconData icon,
  required Color color,
  required Function(QueryDocumentSnapshot?) onChanged,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 80,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Expanded(
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: value != null ? color.withOpacity(0.5) : Colors.white10,
              width: value != null ? 2 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<QueryDocumentSnapshot>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.surfaceDark,
              hint: Text(
                'Select',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              items: widget.teams.map((team) {
                return DropdownMenuItem(
                  value: team,
                  child: Text(
                    team['name'],
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              icon: Icon(Icons.arrow_drop_down, color: color, size: 16),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ),
      ),
    ],
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
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.secondaryDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value != null ? color.withOpacity(0.5) : Colors.white10,
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
              items: widget.teams.map((team) {
                return DropdownMenuItem(
                  value: team,
                  child: Text(
                    team['name'],
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
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