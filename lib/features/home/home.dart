import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/models/medicine_model.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/customer_support_sheet.dart';
import 'search.dart';
import '../cart/address.dart';
import '../cart/cart.dart';
import '../medicine/medicine_detail.dart';
import 'widgets/condition_item.dart';
import 'widgets/prescription_banner.dart';
import 'widgets/trending_card.dart';

class Home extends StatefulWidget {
  final String name;
  final String location;
  final ValueChanged<PlatformFile>? onPrescriptionUpload;

  const Home({
    super.key,
    required this.name,
    this.location = 'Set delivery location',
    this.onPrescriptionUpload,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static List<Medicine> _cachedTrending = const [];
  static DateTime? _trendingFetchedAt;
  static const Duration _trendingTtl = Duration(minutes: 5);

  List<Medicine> _trendingMedicines = [];
  bool _isLoadingTrending = false;

  @override
  void initState() {
    super.initState();
    _fetchTrending();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final cart = context.read<CartNotifier>();
        if (cart.remoteCart == null && !cart.isHydrating) {
          cart.syncRemoteCart(force: false);
        }
      }
    });
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _fetchTrending(force: true),
      context.read<CartNotifier>().refresh(force: true),
    ]);
  }

  Future<void> _fetchTrending({bool force = false}) async {
    if (!force &&
        _cachedTrending.isNotEmpty &&
        _trendingFetchedAt != null &&
        DateTime.now().difference(_trendingFetchedAt!) < _trendingTtl) {
      if (_trendingMedicines.isEmpty) {
        setState(() => _trendingMedicines = _cachedTrending);
      }
      return;
    }
    setState(() => _isLoadingTrending = true);
    try {
      final items = await ApiService.searchMedicines(limit: 20);
      final parsed = items.map((m) => Medicine.fromJson(m)).toList();
      _cachedTrending = parsed;
      _trendingFetchedAt = DateTime.now();
      if (mounted) {
        setState(() {
          _trendingMedicines = parsed;
        });
      }
    } catch (_) {
      // Fallback gracefully if offline
    } finally {
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  // ── Time-of-day greeting ───────────────────────────────────────────────────
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _welcomeRow(context),
              const SizedBox(height: 14),
              _locationChip(context),
              const SizedBox(height: 16),
              _searchBar(context),
              const SizedBox(height: 22),
              PrescriptionBanner(onUploadSelected: widget.onPrescriptionUpload),
              const SizedBox(height: 28),
              _browseByConcernHeader(context),
              const SizedBox(height: 14),
              _conditionRow(),
              const SizedBox(height: 28),
              _trendingHeader(context),
              const SizedBox(height: 14),
              _trendingRow(),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_pharmacy_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'PharmaCustomer',
                maxLines: 1,
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.support_agent_rounded),
          tooltip: '24x7 Help & Support',
          onPressed: () => showCustomerSupportSheet(context),
        ),
        Consumer<CartNotifier>(
          builder: (context, cart, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                tooltip: 'Cart',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const Cart()),
                ),
              ),
              if (cart.totalCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${cart.totalCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
            Positioned(
              right: 10, top: 10,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Section builders ───────────────────────────────────────────────────────

  Widget _welcomeRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WELCOME BACK',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.mutedText, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('$_greeting, ${widget.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20, height: 1.15)),
      ],
    );
  }

  Widget _locationChip(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const Address()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Flexible(child: Text(widget.location, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Search(autoFocus: true)),
      ),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outlineBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Search medicines, brands, generics...',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textDisabled, fontSize: 14))),
          ],
        ),
      ),
    );
  }

  Widget _browseByConcernHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Browse by Condition', style: Theme.of(context).textTheme.headlineSmall),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Search()),
          ),
          child: const Text('View all  ›',
              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _conditionRow() {
    return Row(
      children: const [
        Expanded(
          child: ConditionItem(
            icon: Icons.healing,
            label: 'Fever & Pain',
            iconColor: Colors.red,
            categoryName: 'Fever & Pain',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ConditionItem(
            icon: Icons.medication_liquid,
            label: 'Antibiotics',
            iconColor: Colors.teal,
            categoryName: 'Antibiotics',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ConditionItem(
            icon: Icons.medication,
            label: 'Gastro',
            iconColor: Colors.cyan,
            categoryName: 'Gastro & Acid Reflux',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ConditionItem(
            icon: Icons.category_outlined,
            label: 'All Meds',
            iconColor: AppTheme.primary,
            categoryName: 'All',
          ),
        ),
      ],
    );
  }

  Widget _trendingHeader(BuildContext context) =>
      Text('Trending essentials', style: Theme.of(context).textTheme.headlineSmall);

  Widget _trendingRow() {
    if (_isLoadingTrending && _trendingMedicines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_trendingMedicines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineBorder),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 36),
              const SizedBox(height: 8),
              const Text(
                'No medicines found in central catalogue.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _fetchTrending,
                child: const Text('Pull down or tap to refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _trendingMedicines.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final med = _trendingMedicines[index];
          return SizedBox(
            width: 180,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicineDetail(medicine: med),
                ),
              ),
              child: TrendingCard(
                id: med.id,
                title: med.name,
                subtitle: med.tag ?? med.description,
                price: '₹${med.price}',
                tag: med.requiresPrescription ? 'Rx' : 'OTC',
                tagColor: med.requiresPrescription ? Colors.amber.shade50 : Colors.teal.shade50,
                tagTextColor: med.requiresPrescription ? Colors.amber.shade900 : Colors.teal.shade800,
              ),
            ),
          );
        },
      ),
    );
  }
}
