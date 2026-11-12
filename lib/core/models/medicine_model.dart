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
  final String? tag; // e.g. "Strip of 15"
  final String? category;
  final String? subCategory;
  final String? brand;
  final String? genericName;
  final String? composition;
  final String? dosageForm;
  final String? manufacturer;
  final int? mrpPaise;
  final String? schedule;

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
    this.category,
    this.subCategory,
    this.brand,
    this.genericName,
    this.composition,
    this.dosageForm,
    this.manufacturer,
    this.mrpPaise,
    this.schedule,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final mrpPaiseVal = (json['mrpPaise'] as num?)?.toInt() ?? 0;
    final priceRupees = (mrpPaiseVal > 0)
        ? (mrpPaiseVal / 100).toStringAsFixed(2)
        : (json['price']?.toString() ?? '0.00');
    final isRx = json['isPrescriptionRequired'] as bool? ?? false;
    final scheduleVal = json['schedule'] as String? ?? (isRx ? 'SCHEDULE_H' : 'OTC');
    final generic = json['genericName']?.toString();
    final brandVal = json['brand']?.toString();
    final descParts = [
      if (generic != null && generic.isNotEmpty) generic,
      if (brandVal != null && brandVal.isNotEmpty) brandVal,
    ];
    final desc = descParts.isNotEmpty
        ? descParts.join(' • ')
        : (json['description']?.toString() ?? '');

    return Medicine(
      id: (json['_id'] ?? json['id'])?.toString(),
      medicineCode: json['medicineCode']?.toString(),
      name: json['name']?.toString() ?? '',
      description: desc,
      price: priceRupees,
      mrp: priceRupees,
      discount: json['discount']?.toString() ?? 'Best Price',
      badge: isRx ? 'Prescription Required ($scheduleVal)' : 'OTC',
      requiresPrescription: isRx,
      tag: json['packSize']?.toString() ?? json['tag']?.toString() ?? '1 Unit',
      category: json['category']?.toString(),
      subCategory: json['subCategory']?.toString(),
      brand: brandVal,
      genericName: generic,
      composition: json['composition']?.toString(),
      dosageForm: json['dosageForm']?.toString(),
      manufacturer: json['manufacturer']?.toString(),
      mrpPaise: mrpPaiseVal,
      schedule: scheduleVal,
    );
  }
}

