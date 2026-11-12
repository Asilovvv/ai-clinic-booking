import 'package:flutter/material.dart';

import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../theme.dart';

/// What the owner typed into [BusinessForm].
class BusinessFormValue {
  const BusinessFormValue({
    required this.category,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.openHour,
    required this.closeHour,
    required this.workingDays,
    required this.useTemplate,
  });

  final String category;
  final String name;
  final String description;
  final String address;
  final String phone;
  final int openHour;
  final int closeHour;
  final List<int> workingDays;
  final bool useTemplate;
}

/// Name, contacts and opening hours of a business. Without [initial] it
/// creates one, so it also asks for the niche and offers its typical services.
class BusinessForm extends StatefulWidget {
  const BusinessForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
    this.categories = const [],
    this.saving = false,
  });

  final Business? initial;
  final List<Category> categories;
  final bool saving;
  final String submitLabel;
  final ValueChanged<BusinessFormValue> onSubmit;

  @override
  State<BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends State<BusinessForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late String? _category = widget.initial?.category;
  late int _open = widget.initial?.openHour ?? 9;
  late int _close = widget.initial?.closeHour ?? 18;
  late final Set<int> _days = {...?widget.initial?.workingDays};
  bool _template = true;

  bool get _creating => widget.initial == null;

  @override
  void initState() {
    super.initState();
    if (_creating) _days.addAll([0, 1, 2, 3, 4, 5]);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final category = _category ?? (widget.categories.isEmpty ? null : widget.categories.first.id);
    if (category == null) return;
    widget.onSubmit(BusinessFormValue(
      category: category,
      name: _name.text.trim(),
      description: _description.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      openHour: _open,
      closeHour: _close,
      workingDays: _days.toList()..sort(),
      useTemplate: _template,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget label(String value) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(value, style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        );

    DropdownButtonFormField<int> hour(String title, int value, List<int> options, ValueChanged<int> onChanged) =>
        DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(labelText: title),
          items: [
            for (final h in options) DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
          ],
          onChanged: (h) => onChanged(h ?? value),
        );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_creating) ...[
            label(strings.niche),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in widget.categories)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(category.id), size: 18),
                    showCheckmark: false,
                    label: Text(strings.category(category.id, category.title)),
                    selected: (_category ?? widget.categories.first.id) == category.id,
                    onSelected: (_) => setState(() => _category = category.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: strings.businessName,
              prefixIcon: const Icon(Icons.storefront_outlined),
            ),
            validator: (v) => (v == null || v.trim().length < 2) ? strings.enterBusinessName : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: strings.address, prefixIcon: const Icon(Icons.place_outlined)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: strings.phone, prefixIcon: const Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(labelText: strings.description, alignLabelWithHint: true, counterText: ''),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: hour(strings.opensAt, _open, [for (var h = 0; h < 24; h++) h], (h) => setState(() => _open = h)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hour(
                    strings.closesAt, _close, [for (var h = 1; h <= 24; h++) h], (h) => setState(() => _close = h)),
              ),
            ],
          ),
          label(strings.workingDays),
          Row(
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: day == 6 ? 0 : 6),
                    child: _DayToggle(
                      label: weekdayShort(day, strings.lang),
                      selected: _days.contains(day),
                      onTap: () => setState(() => _days.contains(day) ? _days.remove(day) : _days.add(day)),
                    ),
                  ),
                ),
            ],
          ),
          if (_creating)
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(strings.useTemplate),
              value: _template,
              onChanged: (value) => setState(() => _template = value),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: widget.saving ? null : _submit,
            child: widget.saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

/// One weekday of the "working days" row.
class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : cardColor(scheme),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
