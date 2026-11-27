import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/models/medicine_model.dart';
import '../../core/models/cart_item.dart';
import '../cart/cart.dart';
import '../../core/theme.dart';
import '../prescriptions/prescription_upload_sheet.dart';
import '../../core/services/api_service.dart';
import '../category/category_detail.dart';
import '../medicine/medicine_detail.dart';

class _HealthCategoryItem {
  final String label;
  final String subtitle;
  final String categoryQuery;
  final IconData icon;

  const _HealthCategoryItem({
    required this.label,
    required this.subtitle,
    required this.categoryQuery,
    required this.icon,
  });
}

class Search extends StatefulWidget {
  final VoidCallback? onBack;
  final bool autoFocus;
  const Search({super.key, this.onBack, this.autoFocus = false});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _searchRequestId = 0;
  bool _filterColdChain = false;
  List<Medicine> _liveMedicines = [];
  bool _isSearching = false;
  String _lastCompletedQuery = '';

  @override
  void initState() {
    super.initState();
    // Do not eagerly call API on startup with empty query.
    // When query is empty, _buildBrowseCategoriesView() is rendered.
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _liveMedicines = [];
        _isSearching = false;
        _lastCompletedQuery = '';
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchLiveMedicines(trimmed);
    });
  }

  void _selectTrendingQuery(String text) {
    _debounceTimer?.cancel();
    _searchController.text = text;
    _fetchLiveMedicines(text.trim());
  }

  Future<void> _fetchLiveMedicines(String query) async {
    final currentRequestId = ++_searchRequestId;
    setState(() => _isSearching = true);
    try {
      final items = await ApiService.searchMedicines(search: query.isNotEmpty ? query : null);
      if (mounted && currentRequestId == _searchRequestId) {
        setState(() {
          _liveMedicines = items.map((m) => Medicine.fromJson(m)).toList();
          _lastCompletedQuery = query;
        });
      }
    } catch (_) {
      if (mounted && currentRequestId == _searchRequestId) {
        _lastCompletedQuery = query;
      }
    } finally {
      if (mounted && currentRequestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: AppTheme.text,
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineBorder),
            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: TextField(
            controller: _searchController,
            autofocus: widget.autoFocus,
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _debounceTimer?.cancel();
              final trimmed = val.trim();
              if (trimmed.isNotEmpty) {
                _fetchLiveMedicines(trimmed);
              } else {
                setState(() {
                  _liveMedicines = [];
                  _isSearching = false;
                  _lastCompletedQuery = '';
                });
              }
            },
            decoration: InputDecoration(
              hintText: 'Search medicines, brands, generics...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.primary,
                size: 20,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        setState(() {
                          _searchController.clear();
                          _liveMedicines = [];
                          _isSearching = false;
                          _lastCompletedQuery = '';
                        });
                      },
                    ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          Consumer<CartNotifier>(
            builder: (context, cart, child) => Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppTheme.primary,
                  ),
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
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.totalCount}',
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
        ],
      ),
      body: _buildBody(query),
    );
  }

  Widget _buildBody(String query) {
    if (query.isEmpty) {
      return _buildBrowseCategoriesView();
    }
    if (_isSearching || _lastCompletedQuery != query) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_filterColdChain) {
      return _buildNoFilterMatchView();
    }
    if (_liveMedicines.isEmpty) {
      return _buildNotFoundView(query);
    }
    return _buildSearchResultsView(query);
  }

  // ── Browse categories ─────────────────────────────────────────────────────

  Widget _buildBrowseCategoriesView() {
    return RefreshIndicator(
      onRefresh: () => _fetchLiveMedicines(''),
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Blinkit Trending Searches Strip ─────────────────────────────
            _buildTrendingSearchesStrip(),
            const SizedBox(height: 22),

            // ── 2. Shop by Health Concern Header ───────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: AppTheme.primary, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Browse by Health Concern',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 30),
              child: Text(
                'Certified prescription & OTC medicines delivered in 10 mins',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            // ── 3. Clinical 2-Column Health Category Grid ─────────────────────
            GridView.builder(
              itemCount: _healthCategories.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (context, index) {
                final item = _healthCategories[index];
                return _buildClinicalCategoryCard(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSearchesStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 16),
            SizedBox(width: 5),
            Text(
              'TRENDING SEARCHES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9A3412),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _trendingSearches.map((pill) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _selectTrendingQuery(pill),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_rounded, size: 13, color: AppTheme.mutedText),
                        const SizedBox(width: 5),
                        Text(
                          pill,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalCategoryCard(_HealthCategoryItem item) {
    return Semantics(
      button: true,
      label: '${item.label}, ${item.subtitle}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetail(categoryName: item.categoryQuery),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        color: AppTheme.primaryDark,
                        size: 20,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.mutedText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _trendingSearches = [
    'Dolo 650',
    'Pan D',
    'Paracetamol',
    'Volini Spray',
    'Band-Aid',
    'ORS Electral',
    'Azithral 500',
    'Strepsils',
    'Cetirizine',
    'Vicks Inhaler',
  ];

  static const List<_HealthCategoryItem> _healthCategories = [
    _HealthCategoryItem(
      label: 'Fever & Pain Relief',
      subtitle: 'Dolo 650, Paracetamol, Meftal',
      categoryQuery: 'Fever & Pain',
      icon: Icons.healing_rounded,
    ),
    _HealthCategoryItem(
      label: 'Cough & Cold',
      subtitle: 'Ascoril, Alex, Vicks Inhaler',
      categoryQuery: 'Respiratory & Cold',
      icon: Icons.air_rounded,
    ),
    _HealthCategoryItem(
      label: 'Digestion & Acidity',
      subtitle: 'Pan D, Digene, Gelusil',
      categoryQuery: 'Gastro & Acid Reflux',
      icon: Icons.medication_rounded,
    ),
    _HealthCategoryItem(
      label: 'Antibiotics',
      subtitle: 'Azithral, Augmentin, Amoxyclav',
      categoryQuery: 'Antibiotics',
      icon: Icons.medication_liquid_rounded,
    ),
    _HealthCategoryItem(
      label: 'Cardiac & BP',
      subtitle: 'Telma, Amlong, Atorva',
      categoryQuery: 'Heart & BP',
      icon: Icons.favorite_rounded,
    ),
    _HealthCategoryItem(
      label: 'Diabetes Care',
      subtitle: 'Glycomet, Januvia, Glucometers',
      categoryQuery: 'Diabetes',
      icon: Icons.bloodtype_rounded,
    ),
    _HealthCategoryItem(
      label: 'Skin Care & Infections',
      subtitle: 'Betnovate, Candid, Derma',
      categoryQuery: 'Skin Care',
      icon: Icons.spa_rounded,
    ),
    _HealthCategoryItem(
      label: 'Vitamins & Immunity',
      subtitle: 'Zincovit, Becosules, Supradyn',
      categoryQuery: 'Vitamins & Supplements',
      icon: Icons.wb_sunny_rounded,
    ),
    _HealthCategoryItem(
      label: 'First Aid & Surgical',
      subtitle: 'Band-Aid, Betadine, Dettol',
      categoryQuery: 'First Aid & Surgical',
      icon: Icons.medical_services_rounded,
    ),
    _HealthCategoryItem(
      label: 'Eye & Ear Drops',
      subtitle: 'Ciplox, Otrivin, Refresh Tears',
      categoryQuery: 'Eye & Ear',
      icon: Icons.visibility_rounded,
    ),
    _HealthCategoryItem(
      label: 'Baby & Mother Care',
      subtitle: 'Diapers, Gripe Water, Cerelac',
      categoryQuery: 'Baby & Mother Care',
      icon: Icons.child_care_rounded,
    ),
    _HealthCategoryItem(
      label: 'All Medicines',
      subtitle: 'Browse complete pharmacy catalog',
      categoryQuery: 'All',
      icon: Icons.grid_view_rounded,
    ),
  ];

  Widget _buildSearchResultsView(String query) {
    return RefreshIndicator(
      onRefresh: () => _fetchLiveMedicines(query),
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Showing ${_liveMedicines.length} medicines for',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        query,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.text,
                        ),
                      ),
                      const Text(
                        'Verified authentic supplies from certified pharmacies',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _filterColdChain = !_filterColdChain),
                  icon: const Icon(
                    Icons.filter_list,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  label: const Text(
                    'Filters',
                    style: TextStyle(color: AppTheme.primary, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(color: Colors.teal.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._liveMedicines.map((med) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMedicineCard(
                    medicine: med,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicineDetail(medicine: med),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard({
    required Medicine medicine,
    String? footer,
    VoidCallback? onTap,
  }) {
    final parsedPrice =
        double.tryParse(medicine.price.replaceAll('₹', '').trim()) ?? 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: AppTheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: medicine.requiresPrescription
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          medicine.badge.isNotEmpty
                              ? medicine.badge
                              : (medicine.requiresPrescription
                                  ? 'Rx Required'
                                  : 'OTC'),
                          style: TextStyle(
                            fontSize: 10,
                            color: medicine.requiresPrescription
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicine.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        medicine.description,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      medicine.price.startsWith('₹')
                          ? medicine.price
                          : '₹${medicine.price}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.text,
                      ),
                    ),
                    if (medicine.mrp.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        medicine.mrp.startsWith('₹')
                            ? medicine.mrp
                            : '₹${medicine.mrp}',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (medicine.discount.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        medicine.discount,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                ElevatedButton(
                  onPressed: () => context.read<CartNotifier>().add(
                    CartItem(
                      id: medicine.id ??
                          medicine.medicineCode ??
                          'search_${medicine.name}',
                      name: medicine.name,
                      pack: medicine.tag ?? '1 Unit',
                      price: parsedPrice,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade50,
                    foregroundColor: AppTheme.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(80, 36),
                  ),
                  child: const Text(
                    '+ Add',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(
                footer,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Not found ─────────────────────────────────────────────────────────────

  Widget _buildNotFoundView(String query) {
    return RefreshIndicator(
      onRefresh: () => _fetchLiveMedicines(query),
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.manage_search,
                    size: 36,
                    color: AppTheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Medicine Not Found in Local\nInventory',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find an exact match for "$query" across our dark-store pharmacy clusters.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Prescription & Pharmacist Will Source It',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Our platform pharmacist team will locate this exact molecule or an authorized bio-equivalent substitute directly from central state hubs.',
                    style: TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => showPrescriptionUploadSheet(context),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Upload Prescription Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryDetail(categoryName: 'All')),
                ),
                icon: const Icon(Icons.category_outlined),
                label: const Text('Browse Full Medicine Catalogue'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── No filter match ───────────────────────────────────────────────────────

  Widget _buildNoFilterMatchView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              FilterChip(
                label: const Text('Filters 3'),
                selected: true,
                onSelected: (_) {},
                backgroundColor: Colors.teal.shade50,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Cold-Chain (2°C-8°C) ✕'),
                selected: true,
                onSelected: (_) => setState(() => _filterColdChain = false),
                backgroundColor: AppTheme.primary,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Icon(Icons.filter_alt_off, size: 48, color: AppTheme.primary),
                SizedBox(height: 12),
                Text(
                  'No Medicines Match These Exact Filters',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.text,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Try clearing the filters or searching by a different generic molecule.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _filterColdChain = false),
              icon: const Icon(Icons.refresh),
              label: const Text('Reset All Filters'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
