import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../prescriptions/prescription_vault.dart';
import 'models/patient_profile.dart';
import 'providers/patient_profiles_provider.dart';
import 'repositories/patient_repository.dart';
import 'widgets/add_edit_patient_sheet.dart';
import 'widgets/patient_profile_card.dart';

class SavedPatientProfilesScreen extends StatelessWidget {
  const SavedPatientProfilesScreen({
    super.key,
    required this.userName,
    this.profileImagePath,
  });
  final String userName;
  final String? profileImagePath;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        PatientProfilesProvider(ApiServicePatientRepository(userName))..refresh(),
    child: _ProfilesView(
      userName: userName,
      profileImagePath: profileImagePath,
    ),
  );
}

class _ProfilesView extends StatelessWidget {
  const _ProfilesView({required this.userName, this.profileImagePath});
  final String userName;
  final String? profileImagePath;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text('Saved patient profiles'),
    ),
    body: Consumer<PatientProfilesProvider>(
      builder: (context, state, _) {
        if (state.loading) return const _LoadingProfiles();
        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: state.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final profiles = [...state.profiles]
          ..sort((a, b) {
            if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
            return b.lastUpdated.compareTo(a.lastUpdated);
          });
        return RefreshIndicator(
          onRefresh: state.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            children: [
              Text(
                'Prescriptions for your family',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a patient to view their prescription vault.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ...profiles.asMap().entries.map((entry) {
                final profile = entry.value;
                return TweenAnimationBuilder<double>(
                  key: ValueKey(profile.id),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 180 + entry.key * 45),
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: PatientProfileCard(
                    profile: profile,
                    photoPath: profile.isSelf ? profileImagePath : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PrescriptionVault(
                          patientName: profile.name,
                          patientId: profile.id,
                          allergies: profile.allergies,
                          profileImagePath: profile.isSelf
                              ? profileImagePath
                              : null,
                        ),
                      ),
                    ),
                    onEdit: () => _edit(context, profile),
                    onDefault: () => state.setDefault(profile),
                    onDelete: () => _delete(context, profile),
                  ),
                );
              }),
              if (profiles.length <= 1) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.outlineBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primary, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add family members to manage and upload their prescriptions separately.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Consumer<PatientProfilesProvider>(
        builder: (context, state, _) => ElevatedButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add family member'),
        ),
      ),
    ),
  );

  Future<void> _edit(BuildContext context, [PatientProfile? current]) async {
    final value = await showAddEditPatientSheet(context, profile: current);
    if (value == null || !context.mounted) return;
    final state = context.read<PatientProfilesProvider>();
    final duplicate = state.profiles.any(
      (p) =>
          p.id != value.id &&
          p.name.toLowerCase() == value.name.toLowerCase() &&
          p.relation == value.relation,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A profile with this name and relation already exists.',
          ),
        ),
      );
    }
    final occupiedRelation = state.profiles.any(
      (p) =>
          p.id != value.id &&
          p.relation == value.relation &&
          (value.relation == PatientRelation.father ||
              value.relation == PatientRelation.mother),
    );
    if (occupiedRelation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only one ${value.relation.label} profile can be saved.',
          ),
        ),
      );
      return;
    }
    await state.save(value, add: current == null);
  }

  Future<void> _delete(BuildContext context, PatientProfile profile) async {
    if (profile.isSelf) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: Text(
          'Delete ${profile.name}? Their saved prescriptions will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<PatientProfilesProvider>().delete(profile.id);
    }
  }
}

class _LoadingProfiles extends StatelessWidget {
  const _LoadingProfiles();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(48),
      child: CircularProgressIndicator(color: AppTheme.primary),
    ),
  );
}
