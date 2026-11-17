import 'package:flutter/material.dart';
import '../../../core/theme.dart';  
import '../models/patient_profile.dart';

Future<PatientProfile?> showAddEditPatientSheet(
  BuildContext context, {
  PatientProfile? profile,
}) => showModalBottomSheet<PatientProfile>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _AddEditPatientSheet(profile: profile),
);

class _AddEditPatientSheet extends StatefulWidget {
  const _AddEditPatientSheet({this.profile});
  final PatientProfile? profile;
  @override
  State<_AddEditPatientSheet> createState() => _AddEditPatientSheetState();
}

class _AddEditPatientSheetState extends State<_AddEditPatientSheet> {
  static const List<String> _genderOptions = [
    'Female',
    'Male',
    'Other',
    'Prefer not to say',
  ];

  static String? _normalizeGender(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim().toUpperCase();
    switch (clean) {
      case 'MALE':
      case 'M':
        return 'Male';
      case 'FEMALE':
      case 'F':
        return 'Female';
      case 'OTHER':
      case 'O':
        return 'Other';
      case 'PREFER NOT TO SAY':
      case 'PREFER_NOT_TO_SAY':
        return 'Prefer not to say';
      default:
        for (final option in _genderOptions) {
          if (option.toUpperCase() == clean) {
            return option;
          }
        }
        return null;
    }
  }

  late final _name = TextEditingController(text: widget.profile?.name);
  late final _custom = TextEditingController(
    text: widget.profile?.customRelationLabel,
  );
  late final _phone = TextEditingController(text: widget.profile?.phoneNumber);
  late final _conditionOther = TextEditingController();
  late final _allergyOther = TextEditingController();
  late PatientRelation _relation =
      (widget.profile?.relation == PatientRelation.self && widget.profile?.isSelf != true)
          ? PatientRelation.father
          : (widget.profile?.relation ?? PatientRelation.father);
  late DateTime? _dob = widget.profile?.dob;
  late String? _gender = _normalizeGender(widget.profile?.gender);
  late final _conditions = [...?widget.profile?.chronicConditions];
  late final _allergies = [...?widget.profile?.allergies];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _custom.dispose();
    _phone.dispose();
    _conditionOther.dispose();
    _allergyOther.dispose();
    super.dispose();
  }

  void _addText(TextEditingController c, List<String> list) {
    final value = c.text.trim();
    if (value.isNotEmpty && !list.contains(value)) {
      setState(() => list.add(value));
    }
    c.clear();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height * .9 -
                      MediaQuery.viewInsetsOf(context).bottom)
                  .clamp(320.0, MediaQuery.sizeOf(context).height * .9),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.profile == null
                          ? 'Add family member'
                          : 'Edit patient profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Add health details to help keep their care safe.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _sectionLabel('Patient details'),
                    _field(_name, 'Full name *'),
                    const SizedBox(height: 12),
                    if (widget.profile?.isSelf == true)
                      const InputDecorator(
                        decoration: InputDecoration(labelText: 'Relation'),
                        child: Text('Self'),
                      )
                    else
                      DropdownButtonFormField<PatientRelation>(
                        value: PatientRelation.values
                                .where((e) => e != PatientRelation.self)
                                .contains(_relation)
                            ? _relation
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Relation *',
                        ),
                        items: PatientRelation.values
                            .where((e) => e != PatientRelation.self)
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _relation = v ?? _relation),
                      ),
                    if (_relation == PatientRelation.other) ...[
                      const SizedBox(height: 12),
                      _field(_custom, 'Relationship *'),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dob ?? DateTime(now.year - 30),
                          firstDate: DateTime(1900),
                          lastDate: now,
                        );
                        if (date != null) setState(() => _dob = date);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        alignment: Alignment.centerLeft,
                        side: BorderSide(
                          color: _dob == null
                              ? AppTheme.outlineBorder
                              : AppTheme.primary,
                        ),
                        backgroundColor: _dob == null
                            ? Colors.white
                            : AppTheme.primaryContainer,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dob == null
                                  ? 'Date of birth *'
                                  : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _genderOptions.contains(_gender) ? _gender : null,
                      decoration: const InputDecoration(
                        labelText: 'Gender (optional)',
                      ),
                      items: _genderOptions
                          .map(
                            (e) =>
                                DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('Health & safety'),
                    _healthSection(
                      'Chronic conditions',
                      const ['Diabetes', 'Hypertension', 'Asthma', 'Thyroid'],
                      _conditions,
                      _conditionOther,
                    ),
                    const SizedBox(height: 14),
                    _healthSection(
                      'Known allergies',
                      const ['Penicillin', 'Sulfa drugs', 'Peanuts'],
                      _allergies,
                      _allergyOther,
                      allergy: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Allergies help flag medicines that may be unsafe.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _sectionLabel('Contact details'),
                    _field(
                      _phone,
                      'Phone number (optional)',
                      keyboard: TextInputType.phone,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.error),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      child: Text(
                        widget.profile == null ? 'Add member' : 'Save changes',
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
  );

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
  }) => TextField(
    controller: c,
    keyboardType: keyboard,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(labelText: label),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _healthSection(
    String title,
    List<String> options,
    List<String> selected,
    TextEditingController other, {
    bool allergy = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            if (allergy) ...[
              const Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: AppTheme.warningText,
              ),
              const SizedBox(width: 5),
            ],
            Text(title, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 2,
        children: options
            .map(
              (s) => FilterChip(
                label: Text(s),
                selected: selected.contains(s),
                showCheckmark: true,
                selectedColor: allergy
                    ? AppTheme.warningBg
                    : AppTheme.primaryContainer,
                checkmarkColor: allergy
                    ? AppTheme.warningText
                    : AppTheme.primary,
                labelStyle: TextStyle(
                  color: selected.contains(s)
                      ? allergy
                            ? AppTheme.warningText
                            : AppTheme.primaryDark
                      : AppTheme.textSecondary,
                  fontWeight: selected.contains(s)
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                side: BorderSide(
                  color: selected.contains(s)
                      ? allergy
                            ? AppTheme.warningText
                            : AppTheme.primary
                      : AppTheme.outlineBorder,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (v) =>
                    setState(() => v ? selected.add(s) : selected.remove(s)),
              ),
            )
            .toList(),
      ),
      TextField(
        controller: other,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _addText(other, selected),
        decoration: InputDecoration(
          hintText: 'Add another',
          suffixIcon: IconButton(
            tooltip: 'Add $title',
            onPressed: () => _addText(other, selected),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
      ),
      Wrap(
        spacing: 6,
        children: selected
            .where((s) => !options.contains(s))
            .map(
              (s) => InputChip(
                label: Text(s),
                labelStyle: TextStyle(
                  color: allergy ? AppTheme.warningText : AppTheme.primaryDark,
                ),
                backgroundColor: allergy
                    ? AppTheme.warningBg
                    : AppTheme.primaryContainer,
                deleteIconColor: allergy
                    ? AppTheme.warningText
                    : AppTheme.primaryDark,
                onDeleted: () => setState(() => selected.remove(s)),
              ),
            )
            .toList(),
      ),
    ],
  );

  void _save() {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter a name with at least 2 characters.');
      return;
    }
    if (_dob == null || _dob!.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a valid date of birth.');
      return;
    }
    if (_relation == PatientRelation.other && _custom.text.trim().isEmpty) {
      setState(() => _error = 'Enter the relationship label.');
      return;
    }
    final old = widget.profile;
    Navigator.pop(
      context,
      PatientProfile(
        id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        relation: old?.isSelf == true ? PatientRelation.self : _relation,
        customRelationLabel: _custom.text.trim(),
        dob: _dob,
        gender: _gender ?? '',
        phoneNumber: _phone.text.trim(),
        chronicConditions: List.of(_conditions),
        allergies: List.of(_allergies),
        prescriptionCount: old?.prescriptionCount ?? 0,
        lastUpdated: DateTime.now(),
        isDefault: old?.isDefault ?? false,
        isSelf: old?.isSelf ?? false,
      ),
    );
  }
}
