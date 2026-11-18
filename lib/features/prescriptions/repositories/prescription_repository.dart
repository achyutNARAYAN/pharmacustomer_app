import 'dart:convert';
import 'dart:io';
import '../../../core/storage/key_value_store.dart';

enum PrescriptionStatus {
  noneAttached,
  queued,
  uploading,
  uploaded,
  underReview,
  approved,
  rejected,
  expired,
}

extension PrescriptionStatusUi on PrescriptionStatus {
  String get chipLabel {
    switch (this) {
      case PrescriptionStatus.noneAttached:
        return 'Prescription required';
      case PrescriptionStatus.queued:
      case PrescriptionStatus.uploading:
        return 'Uploading…';
      case PrescriptionStatus.uploaded:
        return 'Ready for verification';
      case PrescriptionStatus.underReview:
        return 'Under review';
      case PrescriptionStatus.approved:
        return 'Approved';
      case PrescriptionStatus.rejected:
        return 'Rejected — re-upload';
      case PrescriptionStatus.expired:
        return 'Expired';
    }
  }
}

class Prescription {
  final String id;
  final String? localId;
  final String source; // 'upload' | 'link'
  final PrescriptionStatus status;
  final String fileName;
  final String mime;
  final int sizeBytes;
  final String? remoteUrl;
  final String? rejectionReason;
  final String? doctorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Prescription({
    required this.id,
    this.localId,
    required this.source,
    required this.status,
    required this.fileName,
    required this.mime,
    required this.sizeBytes,
    this.remoteUrl,
    this.rejectionReason,
    this.doctorName,
    required this.createdAt,
    required this.updatedAt,
  });

  Prescription copyWith({
    String? id,
    String? localId,
    String? source,
    PrescriptionStatus? status,
    String? fileName,
    String? mime,
    int? sizeBytes,
    String? remoteUrl,
    String? rejectionReason,
    String? doctorName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Prescription(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      source: source ?? this.source,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      doctorName: doctorName ?? this.doctorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'localId': localId,
        'source': source,
        'status': status.name,
        'fileName': fileName,
        'mime': mime,
        'sizeBytes': sizeBytes,
        'remoteUrl': remoteUrl,
        'rejectionReason': rejectionReason,
        'doctorName': doctorName,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static Prescription? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final source = json['source'];
    final statusName = json['status'];
    final fileName = json['fileName'];
    final mime = json['mime'];
    final sizeBytes = json['sizeBytes'];
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];

    if (id is! String ||
        source is! String ||
        statusName is! String ||
        fileName is! String ||
        mime is! String ||
        sizeBytes is! int ||
        createdAtRaw is! String ||
        updatedAtRaw is! String) {
      return null;
    }

    final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now().toUtc();
    final updatedAt = DateTime.tryParse(updatedAtRaw) ?? DateTime.now().toUtc();
    final status = PrescriptionStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => PrescriptionStatus.uploaded,
    );

    return Prescription(
      id: id,
      localId: json['localId'] as String?,
      source: source,
      status: status,
      fileName: fileName,
      mime: mime,
      sizeBytes: sizeBytes,
      remoteUrl: json['remoteUrl'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      doctorName: json['doctorName'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class PrescriptionRepository {
  final KeyValueStore store;
  final Directory? appSupportDir;

  PrescriptionRepository({
    required this.store,
    this.appSupportDir,
  });

  String keyFor(String userId) => 'prescriptions.$userId';

  Future<List<Prescription>> hydrate(String userId) async {
    try {
      final key = keyFor(userId);
      final raw = await store.read(key);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return [];

      final data = decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;

      final rawList = data['prescriptions'];
      if (rawList is! List) return [];

      final items = <Prescription>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final p = Prescription.fromJson(item);
          if (p != null) items.add(p);
        }
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  void schedulePersist(String userId, List<Prescription> items) {
    final key = keyFor(userId);
    store.write(
      key,
      jsonEncode({
        'prescriptions': items.map((p) => p.toJson()).toList(),
      }),
    );
  }

  Future<void> wipeUser(String userId) async {
    await store.remove(keyFor(userId));

    // Delete prescription files in rx_uploads if present
    if (appSupportDir != null) {
      final rxDir = Directory('${appSupportDir!.path}/rx_uploads');
      if (await rxDir.exists()) {
        try {
          await rxDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
