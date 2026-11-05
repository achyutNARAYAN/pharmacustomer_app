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

  List<PatientProfile> get cachedProfiles => List.unmodifiable(_cachedProfiles);

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
    final cached = ApiService.cachedCustomerProfile;
    if (cached != null) {
      final cust = (cached['customer'] is Map ? cached['customer'] : cached) as Map<String, dynamic>;
      final members = (cust['familyMembers'] as List<dynamic>? ?? []);
      _appendMembers(members);
    }
  }

  void _appendMembers(List<dynamic> members) {
    for (final m in members) {
      if (m is Map) {
        final id = m['_id'] as String? ?? m['id'] as String? ?? '';
        final name = m['fullName'] as String? ?? m['name'] as String? ?? '';
        if (name.isNotEmpty && !_cachedProfiles.any((p) => (id.isNotEmpty && p.id == id) || p.name == name)) {
          _cachedProfiles.add(
            PatientProfile(
              id: id.isNotEmpty ? id : DateTime.now().microsecondsSinceEpoch.toString(),
              name: name,
              relation: _parseRelation(m['relationship'] as String?),
              gender: m['gender'] as String? ?? '',
              lastUpdated: DateTime.now(),
            ),
          );
        }
      }
    }
  }

  @override
  Future<List<PatientProfile>> getProfiles() async {
    try {
      if (ApiService.token != null) {
        final data = await ApiService.getCustomerProfile();
        if (data != null) {
          final cust = (data['customer'] is Map ? data['customer'] : data) as Map<String, dynamic>;
          final members = (cust['familyMembers'] as List<dynamic>? ?? []);
          _appendMembers(members);
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
        final relStr = switch (profile.relation) {
          PatientRelation.self => 'SELF',
          PatientRelation.father => 'FATHER',
          PatientRelation.mother => 'MOTHER',
          PatientRelation.son => 'SON',
          PatientRelation.daughter => 'DAUGHTER',
          PatientRelation.other => 'OTHER',
        };
        final genStr = switch (profile.gender.trim().toUpperCase()) {
          'MALE' || 'M' => 'MALE',
          'FEMALE' || 'F' => 'FEMALE',
          'PREFER_NOT_TO_SAY' => 'PREFER_NOT_TO_SAY',
          _ => 'OTHER',
        };
        final dob = profile.dob ?? DateTime.now().subtract(const Duration(days: 365 * 30));
        final dobStr = dob.toUtc().toIso8601String();

        await ApiService.addFamilyMember(
          ApiService.currentCustomerId,
          fullName: profile.name,
          relation: relStr,
          gender: genStr,
          dateOfBirth: dobStr,
        );
        final fresh = await ApiService.getCustomerProfile();
        if (fresh != null) {
          final cust = (fresh['customer'] is Map ? fresh['customer'] : fresh) as Map<String, dynamic>;
          final members = (cust['familyMembers'] as List<dynamic>? ?? []);
          _appendMembers(members);
        }
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
