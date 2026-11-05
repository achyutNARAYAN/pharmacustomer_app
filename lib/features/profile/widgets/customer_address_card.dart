import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/customer_address.dart';

/// Card displaying a customer delivery address with type chips, default tag,
/// serviceability indicators, contact info, and edit/delete actions.
class CustomerAddressCard extends StatelessWidget {
  final CustomerAddress address;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  const CustomerAddressCard({
    super.key,
    required this.address,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final isServiceable = address.isServiceable;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : const Color(0xFFE2EFF2),
              width: isSelected ? 2 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Type Badge + Default Badge + Serviceable Tag + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Address Type Badge (HOME, WORK, OTHER)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          address.addressType.icon,
                          size: 15,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          address.typeKey,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Default Badge
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 12, color: Color(0xFFE65100)),
                          SizedBox(width: 3),
                          Text(
                            'DEFAULT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Serviceability Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isServiceable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isServiceable ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isServiceable ? Icons.check_circle_outline : Icons.cancel_outlined,
                          size: 13,
                          color: isServiceable ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isServiceable ? 'Serviceable' : 'Unserviceable',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isServiceable ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit Icon
                  if (onEdit != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 19, color: AppTheme.textSecondary),
                      tooltip: 'Edit ${address.typeKey} address',
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],

                  // Delete Icon
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                      tooltip: 'Delete ${address.typeKey} address',
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Address ID (Subtle)
              if (address.id.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'ID: ${address.id}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),

              // Address Line 1
              Text(
                address.addressLine1,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                  height: 1.25,
                ),
              ),

              // Address Line 2
              if (address.addressLine2.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address.addressLine2,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],

              // Landmark
              if (address.landmark.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Near ${address.landmark}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // City, State - PIN Code
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppTheme.mutedText),
                  const SizedBox(width: 4),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: AppTheme.text),
                        children: [
                          TextSpan(text: '${address.city}, ${address.state} - '),
                          TextSpan(
                            text: address.pinCode,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              const Divider(height: 1, color: Color(0xFFEDF5F7)),
              const SizedBox(height: 8),

              // Contact Details & Default button
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${address.contactName} (${address.contactMobile})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Set as default button (if not default)
                  if (!address.isDefault && onSetDefault != null)
                    TextButton.icon(
                      onPressed: onSetDefault,
                      icon: const Icon(Icons.star_border_rounded, size: 15),
                      label: const Text('Set as default'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.primary,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

