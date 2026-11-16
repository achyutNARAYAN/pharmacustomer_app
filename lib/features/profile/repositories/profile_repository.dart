import 'dart:convert';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/key_value_store.dart';

class UserProfile {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String address;
  final String workAddress;
  final String parentsAddress;
  final String? profileImagePath;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email = '',
    this.address = '',
    this.workAddress = '',
    this.parentsAddress = '',
    this.profileImagePath,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phoneNumber': phoneNumber,
        'email': email,
        'address': address,
        'workAddress': workAddress,
        'parentsAddress': parentsAddress,
        'profileImagePath': profileImagePath,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static UserProfile? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final phoneNumber = json['phoneNumber'];

    if (id is! String || name is! String || phoneNumber is! String) {
      return null;
    }

    final updatedAtRaw = json['updatedAt'];
    final updatedAt =
        updatedAtRaw is String ? DateTime.tryParse(updatedAtRaw) ?? DateTime.now().toUtc() : DateTime.now().toUtc();

    return UserProfile(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      email: (json['email'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      workAddress: (json['workAddress'] as String?) ?? '',
      parentsAddress: (json['parentsAddress'] as String?) ?? '',
      profileImagePath: json['profileImagePath'] as String?,
      updatedAt: updatedAt,
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? address,
    String? workAddress,
    String? parentsAddress,
    String? profileImagePath,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      workAddress: workAddress ?? this.workAddress,
      parentsAddress: parentsAddress ?? this.parentsAddress,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProfileRepository {
  final KeyValueStore store;
  final AppLogger? logger;

  ProfileRepository({
    required this.store,
    this.logger,
  });

  String keyFor(String userId) => 'profile.$userId';

  Future<UserProfile?> hydrate(String userId) async {
    final key = keyFor(userId);
    try {
      final raw = await store.read(key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final data = decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;

      return UserProfile.fromJson(data);
    } catch (e, st) {
      logger?.error('Error hydrating profile for $userId', e, st);
      return null;
    }
  }

  void schedulePersist(UserProfile profile) {
    final key = keyFor(profile.id);
    store.write(key, jsonEncode(profile.toJson()));
  }

  Future<void> wipeUser(String userId) async {
    await store.remove(keyFor(userId));
  }
}
