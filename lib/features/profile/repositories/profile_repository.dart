import '../../../core/logging/app_logger.dart';
import '../../../core/storage/envelope.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/user_data_registry.dart';
import '../../../core/storage/write_coordinator.dart';

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

class ProfileRepository implements UserScopedStore {
  static const int currentVersion = 1;
  final KeyValueStore store;
  final UserDataRegistry userDataRegistry;
  final AppLogger? logger;

  final Map<String, WriteCoordinator> _coordinators = {};

  ProfileRepository({
    required this.store,
    required this.userDataRegistry,
    this.logger,
  }) {
    userDataRegistry.registerStore(this);
  }

  String keyFor(String userId) => 'profile.$userId';

  WriteCoordinator coordinatorFor(String userId) {
    final key = keyFor(userId);
    return _coordinators.putIfAbsent(key, () {
      final c = WriteCoordinator(key: key, logger: logger);
      userDataRegistry.registerCoordinator(c);
      return c;
    });
  }

  Future<UserProfile?> hydrate(String userId) async {
    final key = keyFor(userId);
    try {
      final raw = await store.read(key);
      if (raw == null || raw.isEmpty) return null;

      final envelope = Envelope.decode(raw);
      if (envelope == null || envelope.userId != userId) return null;

      return UserProfile.fromJson(envelope.data);
    } catch (e, st) {
      logger?.error('Error hydrating profile for $userId', e, st);
      return null;
    }
  }

  void schedulePersist(UserProfile profile) {
    final coordinator = coordinatorFor(profile.id);
    coordinator.schedule(() async {
      final key = keyFor(profile.id);
      final envelope = Envelope(
        v: currentVersion,
        savedAt: DateTime.now().toUtc(),
        userId: profile.id,
        data: profile.toJson(),
      );
      await store.write(key, envelope.encode());
    });
  }

  @override
  Future<void> wipeUser(String userId) async {
    final key = keyFor(userId);
    _coordinators[key]?.cancelAndDrop();
    await store.remove(key);
  }
}
