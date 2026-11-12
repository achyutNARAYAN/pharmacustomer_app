import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/medicine_model.dart';
import '../../core/services/api_service.dart';
import 'search.dart';
import '../medicine/medicine_detail.dart';
import 'widgets/condition_item.dart';
import 'widgets/prescription_banner.dart';
import 'widgets/trending_card.dart';

class Home extends StatefulWidget {
  final String name;
  final String location;
  final String? profileImagePath;
  final ValueChanged<PlatformFile>? onPrescriptionUpload;

  const Home({
    super.key,
    required this.name,
    this.location = 'Set delivery location',
    this.profileImagePath,
    this.onPrescriptionUpload,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Medicine> _trendingMedicines = [];
  bool _isLoadingTrending = false;

  @override
  void initState() {
    super.initState();
    _fetchTrending();
  }

  Future<void> _fetchTrending() async {
    setState(() => _isLoadingTrending = true);
    try {
      final items = await ApiService.searchMedicines(limit: 20);
      if (mounted) {
        setState(() {
          _trendingMedicines = items.map((m) => Medicine.fromJson(m)).toList();
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
        onRefresh: _fetchTrending,
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
          Text(AppStrings.appName,
              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
      actions: [
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WELCOME BACK',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.mutedText, letterSpacing: 1)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 100),
              child: Text('$_greeting, ${widget.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20, height: 1.15)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
          ),
          child: CircleAvatar(
            radius: 23,
            backgroundColor: AppTheme.primaryContainer,
            backgroundImage: widget.profileImagePath == null ? null : FileImage(File(widget.profileImagePath!)),
            child: widget.profileImagePath == null ? const Icon(Icons.person, color: AppTheme.primary) : null,
          ),
        ),
      ],
    );
  }

  Widget _locationChip(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
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
        MaterialPageRoute(builder: (_) => const Search()),
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
            const SizedBox(width: 8),
            const Icon(Icons.mic_outlined, color: AppTheme.primary, size: 20),
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
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
