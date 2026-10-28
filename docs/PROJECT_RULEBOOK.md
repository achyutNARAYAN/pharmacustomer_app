# PharmaCustomer App — Project Rulebook & Engineering Standards

## 1. Coding Standards & Best Practices
- **Language & Framework**: Dart 3.x / Flutter 3.x.
- **State Management**: Riverpod (Notifier/AsyncNotifier, StateNotifier where legacy). Maintain unidirectional data flow.
- **Type Safety**: Strictly avoid `dynamic` wherever possible. Use strongly-typed models, Freezed/JSON serializable, or explicit data transfer objects.
- **Immutability**: Domain models and state objects must be immutable (`@immutable`, `final` fields, `copyWith`).
- **Precision & Currency**: Never use floating-point numbers (`double`) for financial calculations or quantities where rounding errors accumulate. Use integer-based paise (e.g. `Money` value object) for all currency representations.
- **Lifecycle & Memory Management**: Dispose all `TextEditingController`, `FocusNode`, `StreamSubscription`, and `Timer` instances in `dispose()` lifecycle hooks.
- **Static Analysis**: Enforce zero analyzer warnings/errors (`flutter analyze`). Follow `pedantic` / `flutter_lints` strict rules.

## 2. Security Requirements
- **Secure Storage**: Tokens (access, refresh), encryption keys, and sensitive user identification must be stored using platform-native secure enclaves (e.g., `flutter_secure_storage` backed by iOS Keychain & Android KeyStore/EncryptedSharedPreferences), never plaintext `SharedPreferences`.
- **Session & Token Hygiene**: Revoke active tokens on logout. Wipe user-scoped cached storage on user switch or logout. Automatic access token refresh using secure refresh token rotation.
- **Transport Security**: Enforce HTTPS/TLS 1.3 exclusively. Validate SSL certificate pinning for mobile release builds to prevent MitM.
- **Input Sanitization & Injection Defense**:
  - Sanitize all text inputs (phone numbers, addresses, search queries) against injection and script attacks.
  - Reject dangerous characters or malformed phone formats (+91 E.164 verification).
  - Strip directory traversal paths (`../`) and dangerous mime types in prescription file uploads.
- **PHI / PII Protection**: Redact customer PII (names, phone numbers, exact addresses) and PHI (prescriptions, diagnostic records, drug lists) from analytics and unencrypted local logs.

## 3. Performance Requirements
- **60/120 FPS Rendering**: No synchronous heavy I/O, parsing, or compute on the Flutter UI thread (Root Isolate). Use `compute()` or background workers for parsing large JSON payloads.
- **Storage Write Throttling**: Batch or debounce persistent storage updates (e.g. cart mutations debounced by 300–500ms) to avoid flash memory thrashing and UI jitter.
- **Asset & Image Optimization**: Cache remote product images using `cached_network_image`. Enforce max dimensions and WebP/compressed formats.
- **Memory Footprint**: Evict old page caches, optimize list rendering using `ListView.builder` / `SliverList` with proper item extents.

## 4. Error Handling Standards
- **Explicit Result Types / Failure Hierarchies**: Model domain failures explicitly (e.g. `AuthFailure`, `CartSyncFailure`, `NetworkFailure`). Avoid uncaught generic exceptions.
- **Graceful Degradation / Offline First**:
  - The cart and browse history must operate seamlessly offline.
  - When network requests fail, queue mutating actions (e.g., cart sync, prescription uploads) with exponential backoff and retry policies.
  - Corrupt storage envelopes must fail safe to clean state without crashing the host application.
- **User-Facing Feedback**: Provide clear, actionable, non-technical error notifications (e.g., SnackBar, Banner) instead of raw stack traces.

## 5. Logging Requirements
- **Structured Logging**: Use an explicit logging utility (`AppLogger`) with severity levels (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `FATAL`).
- **Log Sanitation**: Automatically scrub Authorization headers, passwords, OTPs, session tokens, and patient prescription URLs before emitting log messages.
- **Production Stripping**: Strip verbose/debug logs in release builds (`kReleaseMode`).

## 6. Scalability & Architecture Considerations
- **Streamlined Clean Architecture (Ponytail Standard)**:
  - `presentation`: Widgets, screens, view controllers/providers.
  - `domain`: Entities, value objects, failure definitions, repository contracts.
  - `data`: Repositories directly connecting to centralized `ApiService` (with MockClient test injection) and secure local storage, eliminating redundant remote-data-source wrapper bloat.
- **Optimistic Locking & Concurrency**: Support server revision counters (`If-Match: <revision>`) with conflict resolution (`mergeMaxQuantity`) on shared state like carts.
- **Idempotency**: All payment, order placement, and mutating uploads must require unique client-generated UUID `Idempotency-Key` headers.

## 7. Testing & Quality Assurance Requirements
- **Test Coverage**:
  - **Unit Tests**: 100% of pure domain business logic, math (`Money`), parsers, envelope migrators, and debounce queues.
  - **Widget / Integration Tests**: Every screen and state interaction (auth flow, address picker, cart updates, checkout validation).
  - **End-to-End Tests**: Critical flows (Login -> Browse -> Cart -> Address -> Upload Prescription -> Place Order).
- **Rule of Completion**: No task is marked complete without passing unit/integration tests and zero static analysis warnings.
