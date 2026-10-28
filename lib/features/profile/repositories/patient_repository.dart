import '../../../core/services/api_service.dart';
import '../models/patient_profile.dart';

abstract interface class PatientRepository {
  Future<List<PatientProfile>> getProfiles();
  Future<void> addProfile(PatientProfile profile);
  Future<void> updateProfile(PatientProfile profile);
  Future<void> deleteProfile(String id);
}

class ApiServicePatientRepository implements PatientRepository {
  final String selfName;
  final List<PatientProfile> _cachedProfiles = [];

  ApiServicePatientRepository(this.selfName) {
    _cachedProfiles.add(
      PatientProfile(
        id: 'self',
        name: selfName.isEmpty ? 'You' : selfName,
        relation: PatientRelation.self,
        isSelf: true,
        isDefault: true,
        gender: '',
        lastUpdated: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<PatientProfile>> getProfiles() async {
    try {
      if (ApiService.token != null) {
        final data = await ApiService.getCustomerProfile();
        if (data != null) {
          final members = (data['familyMembers'] as List<dynamic>? ?? []);
          for (final m in members) {
            final id = m['_id'] as String? ?? m['id'] as String? ?? '';
            if (!_cachedProfiles.any((p) => p.id == id)) {
              _cachedProfiles.add(
                PatientProfile(
                  id: id,
                  name: m['fullName'] as String? ?? '',
                  relation: _parseRelation(m['relationship'] as String?),
                  gender: m['gender'] as String? ?? '',
                  lastUpdated: DateTime.now(),
                ),
              );
            }
          }
        }
      }
    } catch (_) {
      // Offline fallback to cached profiles
    }
    return List.unmodifiable(_cachedProfiles);
  }

  PatientRelation _parseRelation(String? rel) {
    if (rel == null) return PatientRelation.other;
    return switch (rel.toLowerCase()) {
      'father' => PatientRelation.father,
      'mother' => PatientRelation.mother,
      'son' => PatientRelation.son,
      'daughter' => PatientRelation.daughter,
      'self' => PatientRelation.self,
      _ => PatientRelation.other,
    };
  }

  @override
  Future<void> addProfile(PatientProfile profile) async {
    _cachedProfiles.add(profile);
    try {
      if (ApiService.token != null) {
        await ApiService.addFamilyMember(
          ApiService.currentCustomerId,
          fullName: profile.name,
          relationship: profile.relation.label,
          age: profile.dob != null
              ? (DateTime.now().year - profile.dob!.year)
              : 30,
          gender: profile.gender.isNotEmpty ? profile.gender : 'Other',
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> updateProfile(PatientProfile profile) async {
    final index = _cachedProfiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) _cachedProfiles[index] = profile;
  }

  @override
  Future<void> deleteProfile(String id) async {
    _cachedProfiles.removeWhere((p) => p.id == id);
  }
}
