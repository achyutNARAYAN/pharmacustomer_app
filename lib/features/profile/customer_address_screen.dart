import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import 'models/customer_address.dart';
import 'providers/customer_address_provider.dart';
import 'repositories/address_repository.dart';
import 'widgets/add_edit_address_sheet.dart';
import 'widgets/customer_address_card.dart';

/// Screen for 5. CUSTOMER ADDRESS MANAGEMENT in Profile.
///
/// Customers can maintain multiple addresses (HOME, WORK, OTHER).
/// Validates whether the PIN code is serviceable before allowing order placement.
class CustomerAddressManagementScreen extends StatelessWidget {
  final String userName;
  final String userPhone;

  const CustomerAddressManagementScreen({
    super.key,
    this.userName = '',
    this.userPhone = '',
  });

  @override
  Widget build(BuildContext context) {
    // If CustomerAddressProvider is already provided in ancestor (e.g. from MultiProvider),
    // we use it. Otherwise, we instantiate a local ChangeNotifierProvider.
    final existingProvider = _findAncestorProvider(context);
    if (existingProvider != null) {
      return _AddressManagementView(
        userName: userName,
        userPhone: userPhone,
      );
    }

    return ChangeNotifierProvider<CustomerAddressProvider>(
      create: (_) => CustomerAddressProvider(ApiServiceAddressRepository())..refresh(),
      child: _AddressManagementView(
        userName: userName,
        userPhone: userPhone,
      ),
    );
  }

  static CustomerAddressProvider? _findAncestorProvider(BuildContext context) {
    try {
      return Provider.of<CustomerAddressProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }
}

class _AddressManagementView extends StatefulWidget {
  final String userName;
  final String userPhone;

  const _AddressManagementView({
    required this.userName,
    required this.userPhone,
  });

  @override
  State<_AddressManagementView> createState() => _AddressManagementViewState();
}

class _AddressManagementViewState extends State<_AddressManagementView> {
  AddressType? _selectedFilter;

  Future<void> _openAddAddress() async {
    final provider = context.read<CustomerAddressProvider>();
    final newAddress = await AddEditAddressSheet.show(
      context,
      defaultContactName: widget.userName,
      defaultContactMobile: widget.userPhone,
    );

    if (newAddress != null && mounted) {
      final saved = await provider.addAddress(newAddress);
      if (!mounted) return;
      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${saved.typeKey} address added successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _openEditAddress(CustomerAddress address) async {
    final provider = context.read<CustomerAddressProvider>();
    final updated = await AddEditAddressSheet.show(
      context,
      initialAddress: address,
      defaultContactName: widget.userName,
      defaultContactMobile: widget.userPhone,
    );

    if (updated != null && mounted) {
      final success = await provider.updateAddress(updated);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updated.typeKey} address updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(CustomerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Address?'),
        content: Text(
          'Are you sure you want to remove this ${address.typeKey} address?\n\n${address.displayDetails}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<CustomerAddressProvider>();
      await provider.deleteAddress(address.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${address.typeKey} address removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Customer Address Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: 'Add new address',
            onPressed: _openAddAddress,
          ),
        ],
      ),
      body: Consumer<CustomerAddressProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.addresses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final allAddresses = provider.addresses;
          final filteredAddresses = provider.filterByType(_selectedFilter);

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F5F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC7EBF0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: AppTheme.primary, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified Doorstep Delivery',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Maintain multiple delivery addresses (HOME, WORK, OTHER). Every address PIN code is checked for dark store serviceability before order authorization.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Type Filter Chips: ALL | HOME | WORK | OTHER
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        label: 'All (${allAddresses.length})',
                        isSelected: _selectedFilter == null,
                        onTap: () => setState(() => _selectedFilter = null),
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        label: 'HOME (${allAddresses.where((a) => a.addressType == AddressType.home).length})',
                        icon: Icons.home_rounded,
                        isSelected: _selectedFilter == AddressType.home,
                        onTap: () => setState(() => _selectedFilter = AddressType.home),
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        label: 'WORK (${allAddresses.where((a) => a.addressType == AddressType.work).length})',
                        icon: Icons.business_rounded,
                        isSelected: _selectedFilter == AddressType.work,
                        onTap: () => setState(() => _selectedFilter = AddressType.work),
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        label: 'OTHER (${allAddresses.where((a) => a.addressType == AddressType.other).length})',
                        icon: Icons.location_on_rounded,
                        isSelected: _selectedFilter == AddressType.other,
                        onTap: () => setState(() => _selectedFilter = AddressType.other),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filteredAddresses.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 54,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter == null
                                ? 'No delivery addresses saved yet.'
                                : 'No ${_selectedFilter!.key} addresses saved.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add your home or work address for fast delivery.',
                            style: TextStyle(fontSize: 13, color: AppTheme.mutedText),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _openAddAddress,
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Add New Address'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredAddresses.asMap().entries.map((entry) {
                    final address = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CustomerAddressCard(
                        address: address,
                        isSelected: provider.selectedAddress?.id == address.id,
                        onTap: () => provider.selectAddress(address),
                        onEdit: () => _openEditAddress(address),
                        onDelete: () => _confirmDelete(address),
                        onSetDefault: () => provider.setDefault(address.id),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAddress,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Add New Address',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0xFFD3E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.primary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
