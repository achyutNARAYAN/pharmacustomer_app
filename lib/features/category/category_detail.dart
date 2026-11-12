import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/models/medicine_model.dart';
import '../../core/services/api_service.dart';
import '../medicine/medicine_detail.dart';
import 'widgets/medicine_list_card.dart';

class CategoryDetail extends StatefulWidget {
  final String categoryName;

  const CategoryDetail({super.key, required this.categoryName});

  @override
  State<CategoryDetail> createState() => _CategoryDetailState();
}

class _CategoryDetailState extends State<CategoryDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Medicine> _medicines = [];
  bool _isLoading = false;

  static const List<String> _tabs = ['All', 'OTC', 'Prescription (Rx)'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fetchMedicines();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMedicines() async {
    setState(() => _isLoading = true);
    try {
      final isAll = widget.categoryName.toLowerCase() == 'all';
      List<Map<String, dynamic>> items = [];
      if (!isAll) {
        items = await ApiService.searchMedicines(
          category: widget.categoryName,
          limit: 50,
        );
      }

      if (items.isEmpty) {
        final allItems = await ApiService.searchMedicines(limit: 50);
        if (isAll) {
          items = allItems;
        } else {
          final queryCat = widget.categoryName.toLowerCase().trim();
          items = allItems.where((m) {
            final cat = (m['category'] ?? '').toString().toLowerCase().trim();
            final subCat = (m['subCategory'] ?? '').toString().toLowerCase().trim();
            return cat.contains(queryCat) || queryCat.contains(cat) || subCat.contains(queryCat);
          }).toList();
          if (items.isEmpty && allItems.isNotEmpty) {
            items = allItems;
          }
        }
      }

      if (mounted) {
        setState(() {
          _medicines = items.map((m) => Medicine.fromJson(m)).toList();
        });
      }
    } catch (_) {
      // Offline fallback
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openMedicineDetail(Medicine med) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineDetail(medicine: med),
      ),
    );
  }

  List<Medicine> _filterByTab(int tabIndex) {
    if (tabIndex == 1) {
      return _medicines.where((m) => !m.requiresPrescription).toList();
    } else if (tabIndex == 2) {
      return _medicines.where((m) => m.requiresPrescription).toList();
    }
    return _medicines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMedicineList(_filterByTab(0)),
          _buildMedicineList(_filterByTab(1)),
          _buildMedicineList(_filterByTab(2)),
        ],
      ),
    );
  }

  Widget _buildMedicineList(List<Medicine> list) {
    if (_isLoading && _medicines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMedicines,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No medicines found for ${widget.categoryName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pull down to refresh or browse all medicines.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _fetchMedicines,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMedicines,
      color: AppTheme.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final med = list[index];
          return MedicineListCard(
            id: med.id,
            name: med.name,
            description: med.description,
            price: '₹${med.price}',
            mrp: '₹${med.mrp}',
            discount: med.discount,
            badge: med.badge,
            requiresPrescription: med.requiresPrescription,
            tag: med.tag ?? '1 Unit',
            onTap: () => _openMedicineDetail(med),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const BackButton(color: AppTheme.text),
      title: Text(
        widget.categoryName,
        style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppTheme.primary),
          onPressed: _fetchMedicines,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.text,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          labelPadding: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: _tabs.map((t) => Tab(child: _TabPill(label: t))).toList(),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  const _TabPill({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}
