class Medicine {
  final String? id;
  final String? medicineCode;
  final String name;
  final String description;
  final String price;
  final String mrp;
  final String discount;
  final String badge;
  final bool requiresPrescription;
  final String? deliveryNote;
  final String? tag; // e.g. "Strip of 15 tablets"

  const Medicine({
    this.id,
    this.medicineCode,
    required this.name,
    required this.description,
    required this.price,
    required this.mrp,
    required this.discount,
    required this.badge,
    required this.requiresPrescription,
    this.deliveryNote,
    this.tag,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final mrpPaise = (json['mrpPaise'] as num?)?.toInt() ?? 0;
    final priceRupees = (mrpPaise / 100).toStringAsFixed(2);
    final isRx = json['isPrescriptionRequired'] as bool? ?? false;
    final schedule = json['schedule'] as String? ?? (isRx ? 'SCHEDULE_H' : 'OTC');

    return Medicine(
      id: json['_id'] as String?,
      medicineCode: json['medicineCode'] as String?,
      name: json['name'] as String? ?? '',
      description: '${json['genericName'] ?? ''} • ${json['brand'] ?? ''}',
      price: priceRupees,
      mrp: priceRupees,
      discount: 'Best Price',
      badge: isRx ? 'Prescription Required ($schedule)' : 'OTC',
      requiresPrescription: isRx,
      tag: json['packSize'] as String? ?? '1 Unit',
    );
  }
}

