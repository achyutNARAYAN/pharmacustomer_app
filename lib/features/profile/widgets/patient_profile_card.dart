import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/patient_profile.dart';
import 'health_chip.dart';

class PatientProfileCard extends StatelessWidget {
  const PatientProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
    required this.onEdit,
    required this.onDefault,
    required this.onDelete,
  });
  final PatientProfile profile;
  final VoidCallback onTap, onEdit, onDefault, onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = switch (profile.relation) {
      PatientRelation.son ||
      PatientRelation.daughter => Icons.child_care_outlined,
      PatientRelation.other => Icons.people_outline,
      _ => Icons.person_outline,
    };
    final age = profile.dob == null
        ? null
        : DateTime.now().difference(profile.dob!).inDays ~/ 365;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.outlineBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: '${profile.relationName} profile for ${profile.name}',
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryContainer,
                  child: Icon(icon, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          profile.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            profile.relationName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                        if (profile.isDefault)
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppTheme.warningText,
                          ),
                      ],
                    ),
                    if (age != null || profile.gender.isNotEmpty)
                      Text(
                        [
                          if (age != null) '$age yrs',
                          if (profile.gender.isNotEmpty) profile.gender,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 5),
                    Text(
                      '${profile.prescriptionCount} prescriptions · Updated ${_date(profile.lastUpdated)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (profile.chronicConditions.isNotEmpty ||
                        profile.allergies.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...profile.chronicConditions.map(
                            (v) => HealthChip(label: v),
                          ),
                          ...profile.allergies.map(
                            (v) => HealthChip(label: v, allergy: true),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Profile actions',
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'default') onDefault();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'default',
                    child: Text('Set as default'),
                  ),
                  if (!profile.isSelf)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}
