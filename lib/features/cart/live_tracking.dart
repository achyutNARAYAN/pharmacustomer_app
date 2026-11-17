import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/utils/address_coordinate_resolver.dart';
import '../orders/providers/orders_provider.dart';
import '../profile/models/customer_address.dart';
import '../profile/providers/customer_address_provider.dart';
import 'models/delivery_tracking_model.dart';

class LiveTracking extends StatefulWidget {
  final String? orderId;
  const LiveTracking({super.key, this.orderId});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  GoogleMapController? _mapController;
  DeliveryTrackingModel? _tracking;
  bool _isLoading = true;
  Timer? _pollTimer;
  List<LatLng>? _cachedRoutePoints;
  LatLng? _cachedDestination;

  @override
  void initState() {
    super.initState();
    _fetchTracking();

    // Periodic live polling (every 15 seconds) to sync real-time driver movement & ETA from backend
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _fetchTracking(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchTracking({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    final cart = context.read<CartNotifier>();
    final profile = context.read<ProfileNotifier>();

    CustomerAddressProvider? addressProvider;
    try {
      addressProvider = Provider.of<CustomerAddressProvider>(context, listen: false);
    } catch (_) {}

    OrdersProvider? ordersProvider;
    try {
      ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    } catch (_) {}

    // ── 1. Resolve Customer Delivery Address dynamically from API & Selected Address ──
    CustomerAddress? activeAddress = addressProvider?.selectedAddress;

    // Check if customer explicitly chose an address during cart/checkout
    if (activeAddress == null && cart.remoteCart?.deliveryAddress != null) {
      final snap = cart.remoteCart!.deliveryAddress!;
      final coords = snap.coordinates;
      final lat = (coords != null && coords.length >= 2) ? coords[1] : 17.4156;
      final lng = (coords != null && coords.length >= 2) ? coords[0] : 78.4351;
      activeAddress = CustomerAddress(
        id: snap.addressId ?? '',
        addressLine1: snap.pincode ?? '',
        city: '',
        state: '',
        pinCode: snap.pincode ?? '',
        contactName: '',
        contactMobile: '',
        latitude: lat,
        longitude: lng,
      );
    }

    // Always fetch live addresses from Address API (/customers/{id}/addresses)
    // to find the user's default address or newly added address
    try {
      final apiAddresses = await ApiService.getAddresses();
      if (apiAddresses.isNotEmpty) {
        // If customer previously selected an address, see if it matches in the API list
        Map<String, dynamic>? targetApiAddr;
        if (activeAddress != null &&
            activeAddress.id.isNotEmpty &&
            !activeAddress.id.startsWith('addr_home_default')) {
          final selectedId = activeAddress.id;
          targetApiAddr = apiAddresses.firstWhere(
            (a) => a['_id'] == selectedId || a['id'] == selectedId,
            orElse: () => apiAddresses.firstWhere(
              (a) => a['isDefault'] == true,
              orElse: () => apiAddresses.first,
            ),
          );
        } else {
          // Use default address from API (isDefault == true)
          targetApiAddr = apiAddresses.firstWhere(
            (a) => a['isDefault'] == true,
            orElse: () => apiAddresses.first,
          );
        }
        activeAddress = CustomerAddress.fromJson(targetApiAddr);
      }
    } catch (_) {}

    // Fallback to addressProvider default only if still null
    activeAddress ??= addressProvider?.defaultAddress;

    // If profile has a custom user-entered address
    String? fallbackAddressText;
    if (profile.address.isNotEmpty && profile.address != 'Set delivery location') {
      fallbackAddressText = profile.address;
    }
    if (activeAddress != null && activeAddress.displayDetails.isNotEmpty) {
      fallbackAddressText = activeAddress.displayDetails;
    }

    final activeOrderId = widget.orderId ?? ordersProvider?.orders.firstOrNull?.orderId;
    final fallbackItems = cart.items.map((i) => i.name).toList();

    Map<String, dynamic>? backendData;
    if (!mounted) return;

    // Resolve true real-world coordinates for the delivery address
    final resolvedCoords = await AddressCoordinateResolver.resolve(
      addressText: fallbackAddressText ?? activeAddress?.displayDetails ?? '',
      pinCode: activeAddress?.pinCode,
      city: activeAddress?.city,
      latitude: activeAddress?.latitude,
      longitude: activeAddress?.longitude,
    );

    var resolvedTracking = DeliveryTrackingModel.fromBackend(
      json: backendData,
      fallbackOrderId: activeOrderId,
      customerAddress: activeAddress,
      fallbackAddressText: fallbackAddressText,
      destinationCoordinates: resolvedCoords,
      fallbackItemCount: cart.totalCount > 0 ? cart.totalCount : null,
      fallbackItemNames: fallbackItems.isNotEmpty ? fallbackItems : null,
    );

    // ── ROAD ROUTE (Backend points if available, otherwise local curved waypoints) ──
    if (resolvedTracking.routePoints.length > 2) {
      _cachedRoutePoints = resolvedTracking.routePoints;
      _cachedDestination = resolvedTracking.destinationLocation;
    } else if (_cachedRoutePoints == null || _cachedDestination != resolvedTracking.destinationLocation) {
      final pts = _generateCurvedRoute(
        resolvedTracking.driverLocation,
        resolvedTracking.destinationLocation,
      );
      _cachedRoutePoints = pts;
      _cachedDestination = resolvedTracking.destinationLocation;
      resolvedTracking = resolvedTracking.copyWith(
        routePoints: pts,
      );
    } else {
      resolvedTracking = resolvedTracking.copyWith(
        routePoints: _cachedRoutePoints,
      );
    }

    if (!mounted) return;

    setState(() {
      _tracking = resolvedTracking;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapBounds());
  }

  static List<LatLng> _generateCurvedRoute(LatLng start, LatLng end) {
    final latDiff = end.latitude - start.latitude;
    final lngDiff = end.longitude - start.longitude;

    return [
      start,
      LatLng(start.latitude + latDiff * 0.20, start.longitude + lngDiff * 0.05),
      LatLng(start.latitude + latDiff * 0.38, start.longitude + lngDiff * 0.32),
      LatLng(start.latitude + latDiff * 0.60, start.longitude + lngDiff * 0.58),
      LatLng(start.latitude + latDiff * 0.82, start.longitude + lngDiff * 0.75),
      LatLng(start.latitude + latDiff * 0.94, start.longitude + lngDiff * 0.96),
      end,
    ];
  }

  void _fitMapBounds() {
    if (_mapController == null || _tracking == null) return;

    final points = _tracking!.routePoints.isNotEmpty
        ? _tracking!.routePoints
        : [
            _tracking!.driverLocation,
            _tracking!.destinationLocation,
          ];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final pt in points) {
      minLat = math.min(minLat, pt.latitude);
      maxLat = math.max(maxLat, pt.latitude);
      minLng = math.min(minLng, pt.longitude);
      maxLng = math.max(maxLng, pt.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 65.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _tracking == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFE4F3F5),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                'Connecting to Live Dispatch System...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tracking = _tracking!;
    final destination = tracking.destinationLocation;

    return Scaffold(
      backgroundColor: const Color(0xFFE4F3F5),
      body: Stack(
        children: [
          // ── Real-Time Interactive Google Map ─────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: tracking.driverLocation,
                zoom: 14.5,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fitMapBounds();
                });
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId('delivery_route'),
                  points: tracking.routePoints,
                  width: 6,
                  color: const Color(0xFF0D9488),
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
              },
              markers: {
                // Destination Home Marker (Customer Address)
                Marker(
                  markerId: const MarkerId('destination'),
                  position: destination,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: InfoWindow(
                    title: 'Delivery Address',
                    snippet: tracking.destinationAddress,
                  ),
                ),
                // Live Moving Driver Marker
                Marker(
                  markerId: const MarkerId('driver'),
                  position: tracking.driverLocation,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: InfoWindow(
                    title: tracking.driverName,
                    snippet: tracking.etaDisplay,
                  ),
                ),
              },
              zoomControlsEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // ── Top Floating Back Button ─────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back, color: AppTheme.text, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Map Floating Zoom In / Zoom Out Controls ──────────────────────
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.add, color: AppTheme.text, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.remove, color: AppTheme.text, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _fitMapBounds,
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.my_location, color: AppTheme.primary, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Expandable Interactive Bottom Sheet ───────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.28,
            maxChildSize: 0.72,
            snap: true,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    // Pull Handle indicator
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Driver Profile & Contact (Backend driven)
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.surfaceLow,
                              child: Icon(
                                Icons.person,
                                color: AppTheme.primary,
                                size: 30,
                              ),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tracking.driverName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                                        const SizedBox(width: 2),
                                        Text(
                                          tracking.driverRating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tracking.driverVehicle,
                                style: const TextStyle(
                                  color: AppTheme.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: AppTheme.primaryContainer,
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: () => _message(
                              context,
                              'Calling ${tracking.driverName} (${tracking.driverPhone})...',
                            ),
                            icon: const Icon(Icons.call_rounded, color: AppTheme.primaryDark),
                            tooltip: 'Call Driver',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppTheme.outlineBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _message(context, 'Delivery instructions recorded for ${tracking.driverName}'),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: const Text('Instructions'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppTheme.outlineBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _message(context, 'Trip tracking link for #${tracking.orderId} copied'),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Share trip'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Real Customer Delivery Address Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC7EBF2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.pin_drop_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DELIVERY ADDRESS · DESTINATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tracking.destinationAddress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.text,
                                  ),
                                ),
                                const Text(
                                  'Live GPS verified destination',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Handover Verification OTP Card (Backend derived)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F2B32), Color(0xFF143D47)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.vpn_key_rounded,
                              color: Color(0xFF5EEAD4),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Handover code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Share only at door with courier',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D454E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF5EEAD4).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              tracking.handoverOtp,
                              style: const TextStyle(
                                color: Color(0xFF5EEAD4),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Package / Medicine contents
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.medical_services_outlined,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${tracking.itemCount} medicine${tracking.itemCount > 1 ? "s" : ""} in insulated pouch',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Cold-Chain Safe',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (tracking.itemNames.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: tracking.itemNames.take(4).map(
                                (name) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
