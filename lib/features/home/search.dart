import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/cart_notifier.dart';
import '../../core/models/medicine_model.dart';
import '../../core/models/cart_item.dart';
import '../cart/cart.dart';
import '../../core/theme.dart';
import '../../core/utils/prescription_uploader.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/api_service.dart';
import '../category/category_detail.dart';
import '../medicine/medicine_detail.dart';

class Search extends StatefulWidget {
  final VoidCallback? onBack;
  const Search({super.key, this.onBack});

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

  @override
  void initState() {
    super.initState();
    _fetchLiveMedicines('');
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchLiveMedicines(val.trim());
    });
  }

  Future<void> _fetchLiveMedicines(String query) async {
    final currentRequestId = ++_searchRequestId;
    setState(() => _isSearching = true);
    try {
      final items = await ApiService.searchMedicines(search: query.isNotEmpty ? query : null);
      if (mounted && currentRequestId == _searchRequestId) {
        setState(() {
          _liveMedicines = items.map((m) => Medicine.fromJson(m)).toList();
        });
      }
    } catch (_) {
      // Fallback gracefully to default items if offline
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
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _debounceTimer?.cancel();
              _fetchLiveMedicines(val.trim());
            },
            decoration: InputDecoration(
              hintText: AppStrings.searchHint,
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
                        setState(() => _searchController.clear());
                        _fetchLiveMedicines('');
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
    if (_isSearching) {
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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text('Browse by Health Concern', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 19)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 26.0, top: 2),
              child: Text(
                'Find certified prescription & OTC medicines',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: const Color(0xFFE7F6F4),
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CategoryDetail(
                      categoryName: 'Fever & Pain',
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.healing,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fever & Pain Relief',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 19,
                                    color: AppTheme.text,
                                  ),
                                ),
                                Text(
                                  'Dolo, Paracetamol, Solo 650 & Analgesics',
                                  style: TextStyle(
                                    color: AppTheme.mutedText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 24,
                            color: AppTheme.mutedText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _chip('Dolo 650 Tablet'),
                                  const SizedBox(width: 6),
                                  _chip('Paracetamol 650mg'),
                                  const SizedBox(width: 6),
                                  _chip('Solo 650 Tablet'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              itemCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 174,
              ),
              itemBuilder: (context, index) => [
                _buildCategoryCard(
                  'Antibiotics',
                  'Azithral, Augmentin & more',
                  'Active Catalogue',
                  Icons.medication_liquid,
                  Colors.teal,
                ),
                _buildCategoryCard(
                  'Gastro & Acid Reflux',
                  'Pan 40, Pantoprazole & antacids',
                  'Active Catalogue',
                  Icons.medication,
                  Colors.cyan,
                ),
                _buildCategoryCard(
                  'Fever & Pain',
                  'Dolo, Solo, Paracetamol',
                  'Active Catalogue',
                  Icons.healing,
                  Colors.red,
                ),
                _buildCategoryCard(
                  'All',
                  'View all medicines in catalogue',
                  'Central Inventory',
                  Icons.inventory_2_outlined,
                  AppTheme.primary,
                ),
                _buildCategoryCard(
                  'Heart & BP',
                  'Statins, monitors & ACE',
                  'Specialized care',
                  Icons.favorite,
                  Colors.purple,
                ),
                _buildCategoryCard(
                  'Respiratory & Cold',
                  'Inhalers, syrups, anti-allergy',
                  'Respiratory Care',
                  Icons.air,
                  Colors.orange,
                ),
              ][index],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    String subtitle,
    String count,
    IconData icon,
    Color color,
  ) {
    return Semantics(
      button: true,
      label: '$title, $count',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CategoryDetail(categoryName: title)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.outlineBorder),
              boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.035), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: color, size: 23),
                    ),
                    Flexible(
                      child: Text(count, textAlign: TextAlign.end,
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.text)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: AppTheme.mutedText, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                    onPressed: () => pickPrescription(context),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available in Central Catalogue',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.text,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoryDetail(categoryName: 'All')),
                  ),
                  child: const Text(
                    'View All >',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAlternativeCard(
              'Dolo 650 Tablet',
              'Paracetamol IP 650mg • Micro Labs Ltd',
              '₹35.00',
              '₹35.00',
              'Strip of 15',
            ),
            const SizedBox(height: 12),
            _buildAlternativeCard(
              'Pan 40 Tablet',
              'Pantoprazole 40mg • Alkem Laboratories Ltd',
              '₹155.00',
              '₹155.00',
              'Strip of 15',
              isDetails: true,
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
                  'We found 0 matches for "Diabetes Care"',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Text(
                'Popular in Central Catalogue',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAlternativeCard(
            'Dolo 650 Tablet',
            'Paracetamol IP 650mg • Micro Labs Ltd',
            '₹35.00',
            '₹35.00',
            'Strip of 15',
          ),
          const SizedBox(height: 12),
          _buildAlternativeCard(
            'Augmentin 625 Duo Tablet',
            'Amoxicillin 500mg + Clavulanic Acid 125mg',
            '₹204.00',
            '₹204.00',
            'Strip of 10',
          ),
        ],
      ),
    );
  }

  // ── Shared card ───────────────────────────────────────────────────────────

  Widget _buildAlternativeCard(
    String name,
    String desc,
    String price,
    String mrp,
    String tag, {
    bool isDetails = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
          ),
          if (isDetails)
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicineDetail(
                    medicine: Medicine(
                      name: name,
                      description: desc,
                      price: price.replaceAll('₹', ''),
                      mrp: price.replaceAll('₹', ''),
                      discount: '',
                      badge: tag,
                      requiresPrescription: tag.toLowerCase().contains('rx'),
                    ),
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(80, 36),
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Details >',
                style: TextStyle(color: AppTheme.primary, fontSize: 11),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => context.read<CartNotifier>().add(
                CartItem(
                  id: 'suggestion_$name',
                  name: name,
                  pack: tag,
                  price: double.parse(price.replaceAll('₹', '')),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(80, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add to Cart', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
