import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/logging/app_logger.dart';
import 'core/providers/cart_notifier.dart';
import 'core/providers/profile_notifier.dart';
import 'core/storage/key_value_store.dart';
import 'core/storage/secure_token_store.dart';
import 'core/storage/shared_preferences_store.dart';
import 'features/auth/models/auth_session.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/cart/models/cart_snapshot.dart';
import 'features/cart/repositories/cart_repository.dart';
import 'features/orders/providers/orders_provider.dart';
import 'features/orders/repositories/orders_repository.dart';
import 'features/prescriptions/providers/prescription_provider.dart';
import 'features/prescriptions/repositories/prescription_repository.dart';
import 'features/profile/providers/customer_address_provider.dart';
import 'features/profile/repositories/address_repository.dart';
import 'features/profile/repositories/profile_repository.dart';
import 'core/services/api_service.dart';
import 'app/app.dart';
import 'features/onboarding/splash.dart';

class AppDependencies {
  final AuthRepository authRepository;
  final CartRepository cartRepository;
  final OrdersRepository ordersRepository;
  final PrescriptionRepository prescriptionRepository;
  final ProfileRepository profileRepository;

  final AuthSession? session;
  final CartSnapshot initialCart;
  final UserProfile? initialProfile;

  AppDependencies({
    required this.authRepository,
    required this.cartRepository,
    required this.ordersRepository,
    required this.prescriptionRepository,
    required this.profileRepository,
    this.session,
    required this.initialCart,
    this.initialProfile,
  });

  static Future<AppDependencies> bootstrap() async {
    final logger = ConsoleLogger();
    final KeyValueStore store = SharedPreferencesStore();
    final SecureTokenStore secureStore = FlutterSecureTokenStore();

    ApiService.logger = logger;

    final authRepo = AuthRepository(
      secureStore: secureStore,
      appSettingsStore: store,
      logger: logger,
    );

    final cartRepo = CartRepository(
      store: store,
      logger: logger,
    );

    final ordersRepo = OrdersRepository(
      store: store,
    );

    final prescriptionRepo = PrescriptionRepository(
      store: store,
    );

    final profileRepo = ProfileRepository(
      store: store,
      logger: logger,
    );

    // 1. Restore auth session first
    RestoreResult authResult;
    try {
      authResult = await authRepo.restoreSession().timeout(const Duration(seconds: 4));
    } catch (_) {
      authResult = const RestoreResult(RestoreResultStatus.unauthenticated);
    }

    final session = authResult.session;
    final userId = session?.userId;

    // 2. Hydrate user-scoped stores independently
    CartSnapshot initialCart = CartSnapshot.empty;
    UserProfile? initialProfile;

    try {
      final results = await Future.wait([
        cartRepo.hydrate(userId).timeout(const Duration(seconds: 3)),
        if (userId != null)
          profileRepo.hydrate(userId).timeout(const Duration(seconds: 3))
        else
          Future.value(null),
      ]);
      initialCart = results[0] as CartSnapshot;
      initialProfile = results[1] as UserProfile?;
    } catch (e) {
      logger.warning('Bootstrap user hydration fallback', e);
    }

    return AppDependencies(
      authRepository: authRepo,
      cartRepository: cartRepo,
      ordersRepository: ordersRepo,
      prescriptionRepository: prescriptionRepo,
      profileRepository: profileRepo,
      session: session,
      initialCart: initialCart,
      initialProfile: initialProfile,
    );
  }
}

class BootstrapGate extends StatefulWidget {
  final Future<AppDependencies> dependenciesFuture;
  final AppDependencies? initialDeps;

  const BootstrapGate({
    super.key,
    required this.dependenciesFuture,
    this.initialDeps,
  });

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  AppDependencies? _deps;

  @override
  void initState() {
    super.initState();
    _deps = widget.initialDeps;
    if (_deps == null) {
      widget.dependenciesFuture.then((deps) {
        if (mounted) {
          setState(() {
            _deps = deps;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = _deps;
    if (deps == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Splash(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            deps.authRepository,
            initial: deps.session,
            onWipeUser: (uid) => Future.wait([
              deps.cartRepository.wipeUser(uid),
              deps.profileRepository.wipeUser(uid),
              deps.ordersRepository.wipeUser(uid),
              deps.prescriptionRepository.wipeUser(uid),
            ]),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CartNotifier>(
          create: (_) => CartNotifier(deps.cartRepository, deps.initialCart),
          update: (_, auth, cart) => cart!..bindUser(auth.userId),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProfileNotifier>(
          create: (_) => ProfileNotifier(deps.profileRepository, deps.initialProfile),
          update: (_, auth, profile) => profile!..bindUser(auth.userId),
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrdersProvider>(
          create: (_) => OrdersProvider(deps.ordersRepository),
          update: (_, auth, orders) => orders!..bindUser(auth.userId),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PrescriptionProvider>(
          create: (_) => PrescriptionProvider(deps.prescriptionRepository),
          update: (_, auth, rx) => rx!..bindUser(auth.userId),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CustomerAddressProvider>(
          create: (_) => CustomerAddressProvider(ApiServiceAddressRepository()),
          update: (_, auth, addr) => addr!..bindUser(auth.userId),
        ),
      ],
      child: const App(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapFuture = AppDependencies.bootstrap();
  final initialDeps = await bootstrapFuture;
  runApp(
    BootstrapGate(
      dependenciesFuture: bootstrapFuture,
      initialDeps: initialDeps,
    ),
  );
}
