import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/errors/failures.dart';
import '../../../core/providers/load_status.dart';
import '../../../core/services/api_service.dart';
import '../repositories/prescription_repository.dart';

class PrescriptionProvider extends ChangeNotifier {
  final PrescriptionRepository? _repository;
  final List<Prescription> _prescriptions = [];

  String? _userId;
  LoadStatus _status = LoadStatus.uninitialized;
  bool _disposed = false;
  Future<void>? _inFlightSync;
  DateTime? _lastSyncedAt;
  static const Duration _staleDuration = Duration(minutes: 3);

  PrescriptionProvider([this._repository, List<Prescription>? initial]) {
    if (initial != null) {
      _prescriptions.addAll(initial);
      _status = LoadStatus.ready;
    }
  }

  List<Prescription> get prescriptions => List.unmodifiable(_prescriptions);
  LoadStatus get status => _status;

  PrescriptionStatus get latestStatus {
    if (_prescriptions.isEmpty) return PrescriptionStatus.noneAttached;
    return _prescriptions.first.status;
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void addPrescription(Prescription prescription) {
    _prescriptions.insert(0, prescription);
    if (_repository != null && _userId != null) {
      _repository.schedulePersist(_userId!, _prescriptions);
    }
    _safeNotify();
  }

  Future<({bool success, String? message})> deletePrescription(String prescriptionId) async {
    final cleanId = prescriptionId.trim();
    if (cleanId.isEmpty) return (success: false, message: 'Invalid prescription ID');

    final isLocalOnly = cleanId.startsWith('rx_');

    _prescriptions.removeWhere((p) => p.id == cleanId);
    if (_repository != null && _userId != null) {
      _repository.schedulePersist(_userId!, _prescriptions);
    }
    _safeNotify();

    if (ApiService.token != null && !isLocalOnly) {
      try {
        await ApiService.deletePrescription(cleanId);
        return (success: true, message: null);
      } catch (e) {
        debugPrint('[PrescriptionProvider] deletePrescription API error: $e');
        final String errorMsg = e is Failure ? e.message : e.toString();
        return (success: false, message: errorMsg);
      }
    }
    return (success: true, message: null);
  }

  void archivePrescription(String prescriptionId) {
    final index = _prescriptions.indexWhere((p) => p.id == prescriptionId);
    if (index != -1) {
      final old = _prescriptions[index];
      _prescriptions[index] = Prescription(
        id: old.id,
        localId: old.localId,
        source: old.source,
        status: PrescriptionStatus.expired,
        fileName: old.fileName,
        mime: old.mime,
        sizeBytes: old.sizeBytes,
        remoteUrl: old.remoteUrl,
        rejectionReason: old.rejectionReason,
        doctorName: old.doctorName,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      if (_repository != null && _userId != null) {
        _repository.schedulePersist(_userId!, _prescriptions);
      }
      _safeNotify();
    }
  }

  Future<void> init() async {
    if (_repository == null || _userId == null) {
      _status = LoadStatus.ready;
      _safeNotify();
      return;
    }

    _status = LoadStatus.hydrating;
    _safeNotify();

    // Hydrate local cache only; remote prescriptions load lazily on tab visit.
    final loaded = await _repository.hydrate(_userId!);
    _prescriptions.clear();
    _prescriptions.addAll(loaded);
    _lastSyncedAt = null;

    _status = LoadStatus.ready;
    _safeNotify();
  }

  /// Ensures prescriptions are synced from the server if missing or stale.
  Future<void> ensureLoaded() => syncRemotePrescriptions(force: false);

  Future<void> syncRemotePrescriptions({bool force = false}) {
    if (_repository == null || _userId == null || ApiService.token == null) {
      return Future.value();
    }
    if (!force &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _staleDuration) {
      return Future.value();
    }
    if (_inFlightSync != null) {
      return _inFlightSync!;
    }

    final future = _doSyncRemotePrescriptions();
    _inFlightSync = future;
    future.whenComplete(() {
      if (identical(_inFlightSync, future)) {
        _inFlightSync = null;
      }
    });
    return future;
  }

  Future<void> _doSyncRemotePrescriptions() async {
    if (_repository == null || _userId == null || ApiService.token == null) return;
    try {
      final remoteItems = await ApiService.listPrescriptions(customerId: _userId);
      _lastSyncedAt = DateTime.now();
      if (remoteItems.isNotEmpty) {
        for (final item in remoteItems) {
          final rxId = (item['prescriptionId'] ??
                  item['_id'] ??
                  item['id'] ??
                  item['rxId'] ??
                  '')
              .toString();
          if (rxId.isEmpty) continue;

          final statusStr = (item['status'] as String? ?? '').toUpperCase();
          final status = switch (statusStr) {
            'APPROVED' => PrescriptionStatus.approved,
            'REJECTED' => PrescriptionStatus.rejected,
            'EXPIRED' => PrescriptionStatus.expired,
            'PENDING' || 'UNDER_REVIEW' || 'IN_REVIEW' || 'PENDING_REVIEW' || 'IN_PROGRESS' => PrescriptionStatus.underReview,
            _ => PrescriptionStatus.underReview,
          };

          final existingIndex = _prescriptions.indexWhere((p) => p.id == rxId);
          if (existingIndex >= 0) {
            _prescriptions[existingIndex] = _prescriptions[existingIndex].copyWith(
              status: status,
              remoteUrl: item['documentUrl'] as String? ?? _prescriptions[existingIndex].remoteUrl,
              doctorName: item['doctorName'] as String? ?? _prescriptions[existingIndex].doctorName,
              updatedAt: DateTime.now(),
            );
          } else {
            _prescriptions.add(
              Prescription(
                id: rxId,
                source: 'upload',
                status: status,
                fileName: item['fileName'] as String? ?? 'Prescription.pdf',
                mime: item['mimeType'] as String? ?? 'application/pdf',
                sizeBytes: (item['fileSize'] as num?)?.toInt() ?? 1024,
                remoteUrl: item['documentUrl'] as String?,
                doctorName: item['doctorName'] as String?,
                createdAt: DateTime.tryParse(item['prescriptionDate'] as String? ?? '') ?? DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          }
        }
        _repository.schedulePersist(_userId!, _prescriptions);
        _safeNotify();
      }
    } catch (_) {}
  }

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _lastSyncedAt = null;

    scheduleMicrotask(() async {
      if (_disposed) return;
      await init();
    });
  }

  Future<void> refresh({bool force = true}) async {
    await syncRemotePrescriptions(force: force);
  }

  void reset() {
    _prescriptions.clear();
    _status = LoadStatus.ready;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
