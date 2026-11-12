import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/owner_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

const _durations = [30, 60, 90, 120, 150, 180];

/// What the business offers and who works there.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  Future<void> _editService(BuildContext context, Business business, [Service? service]) async {
    final cubit = context.read<OwnerCubit>();
    final input = await showDialog<_ServiceInput>(
      context: context,
      builder: (_) => _ServiceDialog(service: service, specialists: business.specialists),
    );
    if (input == null) return;
    await cubit.saveService(
      id: service?.id,
      name: input.name,
      durationMin: input.durationMin,
      price: input.price,
      description: service?.description ?? '',
      specialistIds: input.specialistIds,
    );
  }

  Future<void> _editSpecialist(BuildContext context, [Specialist? specialist]) async {
    final cubit = context.read<OwnerCubit>();
    final input = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _SpecialistDialog(specialist: specialist),
    );
    if (input == null) return;
    await cubit.saveSpecialist(id: specialist?.id, name: input.$1, title: input.$2);
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final strings = context.read<SettingsCubit>().state.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteQuestion(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.no)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(strings.delete)),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final business = context.select((OwnerCubit cubit) => cubit.state.business);
    if (business == null) return const SizedBox.shrink();
    final names = {for (final s in business.specialists) s.id: s.name};
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      children: [
        SectionTitle(
          strings.services,
          trailing: TextButton.icon(
            onPressed: () => _editService(context, business),
            icon: const Icon(Icons.add),
            label: Text(strings.addService),
          ),
        ),
        if (business.services.isEmpty)
          AppCard(child: Text(strings.noServices, style: text.bodyMedium)),
        for (final service in business.services)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              onTap: () => _editService(context, business, service),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${formatDuration(service.durationMin, strings)} · ${formatMoney(service.price, strings)}',
                          style: text.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          service.specialistIds.map((id) => names[id]).whereType<String>().join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: strings.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final cubit = context.read<OwnerCubit>();
                      if (await _confirmDelete(context, service.name)) await cubit.deleteService(service.id);
                    },
                  ),
                ],
              ),
            ),
          ),
        SectionTitle(
          strings.staff,
          trailing: TextButton.icon(
            onPressed: () => _editSpecialist(context),
            icon: const Icon(Icons.add),
            label: Text(strings.addSpecialist),
          ),
        ),
        for (final specialist in business.specialists)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              onTap: () => _editSpecialist(context, specialist),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      specialist.initials,
                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(specialist.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        if (specialist.title.isNotEmpty) Text(specialist.title, style: muted),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: strings.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final cubit = context.read<OwnerCubit>();
                      if (await _confirmDelete(context, specialist.name)) await cubit.deleteSpecialist(specialist.id);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ServiceInput {
  const _ServiceInput(this.name, this.durationMin, this.price, this.specialistIds);

  final String name;
  final int durationMin;
  final int price;
  final List<int> specialistIds;
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({required this.specialists, this.service});

  final Service? service;
  final List<Specialist> specialists;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _price = TextEditingController(text: widget.service == null ? '' : '${widget.service!.price}');
  late int _duration = widget.service?.durationMin ?? 60;

  /// A new service is performed by everyone until the owner narrows it down.
  late final Set<int> _performers = {
    ...(widget.service?.specialistIds ?? widget.specialists.map((s) => s.id)),
  };

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _performers.isEmpty) return;
    Navigator.pop(
      context,
      _ServiceInput(_name.text.trim(), _duration, int.parse(_price.text), _performers.toList()..sort()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.service == null ? strings.addService : strings.editService),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                autofocus: widget.service == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: strings.serviceName),
                validator: (v) => (v == null || v.trim().length < 2) ? strings.serviceName : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _duration,
                      decoration: InputDecoration(labelText: strings.duration),
                      items: [
                        for (final minutes in _durations)
                          DropdownMenuItem(value: minutes, child: Text(formatDuration(minutes, strings))),
                      ],
                      onChanged: (value) => setState(() => _duration = value ?? _duration),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      decoration: InputDecoration(labelText: strings.price),
                      validator: (v) => (v == null || int.tryParse(v) == null) ? strings.price : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(strings.performedBy, style: text.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final specialist in widget.specialists)
                    FilterChip(
                      label: Text(specialist.name),
                      selected: _performers.contains(specialist.id),
                      onSelected: (on) =>
                          setState(() => on ? _performers.add(specialist.id) : _performers.remove(specialist.id)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.close)),
        FilledButton(onPressed: _performers.isEmpty ? null : _submit, child: Text(strings.save)),
      ],
    );
  }
}

/// Name and title of a specialist; returns (name, title).
class _SpecialistDialog extends StatefulWidget {
  const _SpecialistDialog({this.specialist});

  final Specialist? specialist;

  @override
  State<_SpecialistDialog> createState() => _SpecialistDialogState();
}

class _SpecialistDialogState extends State<_SpecialistDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.specialist?.name ?? '');
  late final _title = TextEditingController(text: widget.specialist?.title ?? '');

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (_name.text.trim(), _title.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(widget.specialist == null ? strings.addSpecialist : strings.editSpecialist),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: widget.specialist == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: strings.specialistName),
              validator: (v) => (v == null || v.trim().length < 2) ? strings.enterName : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: strings.specialistTitle),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.close)),
        FilledButton(onPressed: _submit, child: Text(strings.save)),
      ],
    );
  }
}
