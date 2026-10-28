/// API Constants based on MDP OpenAPI specifications
/// Live Base URL: https://mdp-mvp.onrender.com/api/v1
abstract final class ApiConstants {
  static const String baseUrl = 'https://mdp-mvp.onrender.com/api/v1';

  // ── Auth Endpoints ───────────────────────────────────────────────────────────
  static const String sendOtp = '/customers/auth/send-otp';
  static const String verifyOtp = '/customers/auth/verify-otp';
  static const String register = '/customers/auth/register';

  // ── Customer Profile & Family Patients ─────────────────────────────────────────
  static String customerProfile(String customerId) => '/customers/$customerId';
  static String customerFamilyMembers(String customerId) => '/customers/$customerId/family-members';

  // ── Delivery Addresses (GeoJSON) ─────────────────────────────────────────────
  static String customerAddresses(String customerId) => '/customers/$customerId/addresses';
  static String customerAddressDetail(String customerId, String addressId) => '/customers/$customerId/addresses/$addressId';

  // ── Central Medicine Catalogue ───────────────────────────────────────────────
  static const String medicines = '/medicines';
  static String medicineDetail(String medicineId) => '/medicines/$medicineId';

  // ── Digital Prescriptions ───────────────────────────────────────────────────
  static const String prescriptions = '/prescriptions';
  static String prescriptionDetail(String prescriptionId) => '/prescriptions/$prescriptionId';

  // ── Cart & 4km Store Allocation (Module 5) ────────────────────────────────────
  static const String cart = '/cart';
  static const String cartItems = '/cart/items';
  static const String cartCheckout = '/cart/checkout';

  // ── Orders & Payments ────────────────────────────────────────────────────────
  static const String orders = '/orders';
  static const String initiatePayment = '/payments/initiate';
  static String deliveryTracking(String orderId) => '/delivery/$orderId/tracking';
}
