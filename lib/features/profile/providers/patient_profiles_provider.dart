import 'package:flutter/foundation.dart';

import '../models/patient_profile.dart';
import '../repositories/patient_repository.dart';

class PatientProfilesProvider extends ChangeNotifier {
  PatientProfilesProvider(this.repository) {
    if (repository is ApiServicePatientRepository) {
      final initial = (repository as ApiServicePatientRepository).cachedProfiles;
      if (initial.isNotEmpty) {
        profiles = initial;
        loading = false;
      }
    }
  }
  final PatientRepository repository;
  List<PatientProfile> profiles = const [];
  bool loading = true;
  String? error;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (profiles.isEmpty) {
      loading = true;
      _safeNotify();
    }
    error = null;
    try {
      profiles = await repository.getProfiles();
    } catch (_) {
      error = 'We couldn’t load patient profiles.';
    }
    loading = false;
    _safeNotify();
  }

  Future<void> save(PatientProfile profile, {bool add = false}) async {
    if (add) {
      await repository.addProfile(profile);
    } else {
      await repository.updateProfile(profile);
    }
    await refresh();
  }

  Future<void> delete(String id) async {
    await repository.deleteProfile(id);
    await refresh();
  }

  Future<void> setDefault(PatientProfile profile) async {
    for (final patient in profiles) {
      await repository.updateProfile(
        patient.copyWith(isDefault: patient.id == profile.id),
      );
    }
    await refresh();
  }
}
