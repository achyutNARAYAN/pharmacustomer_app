import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/models/medicine_model.dart';
import '../../core/widgets/section_header.dart';
import '../medicine/medicine_detail.dart';
import 'cgm_sub_category.dart';
import 'widgets/device_grid_card.dart';
import 'widgets/filter_sort_sheet.dart';
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
  int _appliedFilters = 0;

  static const List<String> _tabs = ['All', 'Oral Medications', 'Insulin & Devices'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6FAFB),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FilterSortSheet(totalItems: 48, categoryName: widget.categoryName),
    );
    if (count != null && mounted) setState(() => _appliedFilters = count);
  }

  void _openMedicineDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MedicineDetail(
          medicine: Medicine(
            name: 'Janumet 50mg/500mg Tablet',
            description: 'Sitagliptin (50mg) + Metformin HCl (500mg)',
            price: '485.00',
            mrp: '550.00',
            discount: '12% OFF',
            badge: 'Prescription Required',
            requiresPrescription: true,
            tag: 'Strip of 15 tablets',
          ),
        ),
      ),
    );
  }

  void _openCgmScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CgmSubCategory()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllTab(onFilterTap: _openFilterSheet, onMedicineTap: _openMedicineDetail, onCgmTap: _openCgmScreen, appliedFilters: _appliedFilters),
          _OralMedicationsTab(onMedicineTap: _openMedicineDetail),
          _InsulinDevicesTab(onCgmTap: _openCgmScreen),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

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
        IconButton(icon: const Icon(Icons.search, color: AppTheme.text), onPressed: () => Navigator.pop(context)),
        IconButton(icon: const Icon(Icons.share_outlined, color: AppTheme.text), onPressed: () {}),
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
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

// ── Tab bodies ─────────────────────────────────────────────────────────────

class _AllTab extends StatelessWidget {
  final VoidCallback onFilterTap;
  final VoidCallback onMedicineTap;
  final VoidCallback onCgmTap;
  final int appliedFilters;

  const _AllTab({required this.onFilterTap, required this.onMedicineTap, required this.onCgmTap, required this.appliedFilters});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Prescribed ──────────────────────────────────────────────
          SectionHeader(
            title: 'Top Prescribed Oral Drugs',
            subtitle: 'Verified clinical therapeutic formulas',
            trailingLabel: 'View All',
          ),
          const SizedBox(height: 12),
          MedicineListCard(
            name: 'Glycomet-GP 2 Forte',
            description: 'Metformin 1000mg + Glimepiride 2mg',
            price: '₹148.50',
            mrp: '₹175.00',
            discount: '15% OFF',
            badge: 'Rx required',
            requiresPrescription: true,
            tag: 'Strip of 15 tablets',
            onTap: onMedicineTap,
          ),
          const SizedBox(height: 10),
          MedicineListCard(
            name: 'Forxiga 10mg',
            description: 'Dapagliflozin Propanediol (10mg)',
            price: '₹572.00',
            mrp: '₹635.00',
            discount: '10% OFF',
            badge: 'Rx required',
            requiresPrescription: true,
            tag: 'Strip of 10 tablets',
            onTap: onMedicineTap,
          ),
          const SizedBox(height: 24),
          // ── Devices ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Monitoring devices & strips',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.text)),
                    SizedBox(height: 3),
                    Text('Reliable tools for everyday monitoring',
                        style: TextStyle(color: AppTheme.mutedText, fontSize: 12)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onFilterTap,
                icon: const Icon(Icons.filter_list, size: 14, color: AppTheme.primary),
                label: Text(appliedFilters == 0 ? 'Filter' : 'Filter ($appliedFilters)', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 12) / 2;
              final tileHeight = (tileWidth / 0.58).clamp(296.0, double.infinity);
              return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: tileWidth / tileHeight,
            children: [
              DeviceGridCard(
                name: 'Accu-Chek Active Glucometer Kit',
                description: 'With 10 free test strips + lancing pen',
                price: '₹1,149',
                mrp: '₹1,599',
                discountBadge: '28% OFF',
                rating: 4.8,
                reviewCount: '1.2k',
                onTap: onCgmTap,
              ),
              DeviceGridCard(
                name: 'OneTouch Select Plus Test Strips',
                description: 'Pack of 50 strips • High accuracy',
                price: '₹980',
                mrp: '₹1,150',
                discountBadge: '15% OFF',
                rating: 4.9,
                reviewCount: '3.4k',
                onTap: onCgmTap,
              ),
              DeviceGridCard(
                name: 'Dr. Morepen Sterile Lancets',
                description: 'Round sterile needles • 100 count',
                price: '₹240',
                mrp: '₹370',
                discountBadge: '35% OFF',
                rating: 4.6,
                reviewCount: '810',
                onTap: onCgmTap,
              ),
              DeviceGridCard(
                name: 'FreeStyle Libre CGM Sensor',
                description: '14-day continuous glucose monitoring',
                price: '₹4,999',
                mrp: '₹5,550',
                discountBadge: '10% OFF',
                rating: 4.9,
                reviewCount: '2.1k',
                onTap: onCgmTap,
              ),
            ],
          );
            },
          ),
        ],
      ),
    );
  }
}

class _OralMedicationsTab extends StatelessWidget {
  final VoidCallback onMedicineTap;
  const _OralMedicationsTab({required this.onMedicineTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MedicineListCard(
          name: 'Glycomet-GP 2 Forte',
          description: 'Metformin (1000mg) + Glimepiride (2mg)',
          price: '₹148.50',
          mrp: '₹175.00',
          discount: '15% OFF',
          badge: 'Req Required',
          requiresPrescription: true,
          tag: 'Strip of 15 tablets',
          onTap: onMedicineTap,
        ),
        const SizedBox(height: 10),
        MedicineListCard(
          name: 'Forxiga 10mg',
          description: 'Dapagliflozin Propanediol (10mg)',
          price: '₹572.00',
          mrp: '₹635.00',
          discount: '10% OFF',
          badge: 'Req Required',
          requiresPrescription: true,
          tag: 'Strip of 10 tablets',
          onTap: onMedicineTap,
        ),
        const SizedBox(height: 10),
        MedicineListCard(
          name: 'Janumet 50mg/500mg Tablet',
          description: 'Sitagliptin (50mg) + Metformin HCl (500mg)',
          price: '₹485.00',
          mrp: '₹550.00',
          discount: '12% OFF',
          badge: 'Rx required',
          requiresPrescription: true,
          tag: 'Strip of 15 tablets',
          onTap: onMedicineTap,
        ),
      ],
    );
  }
}

class _InsulinDevicesTab extends StatelessWidget {
  final VoidCallback onCgmTap;
  const _InsulinDevicesTab({required this.onCgmTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.55,
        children: [
          DeviceGridCard(
            name: 'FreeStyle Libre CGM Sensor',
            description: '14-day continuous glucose monitoring',
            price: '₹4,999',
            mrp: '₹5,550',
            discountBadge: '10% OFF',
            rating: 4.9,
            reviewCount: '2.1k',
            onTap: onCgmTap,
          ),
          DeviceGridCard(
            name: 'Accu-Chek Active Glucometer Kit',
            description: 'With 10 free test strips + lancing pen',
            price: '₹1,149',
            mrp: '₹1,599',
            discountBadge: '28% OFF',
            rating: 4.8,
            reviewCount: '1.2k',
            onTap: onCgmTap,
          ),
        ],
      ),
    );
  }
}
