import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/booking_cubit.dart';
import '../../bloc/load_status.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import 'common.dart';

/// What to do with the chosen slot. The client's name and phone are only
/// filled in when the owner books by hand.
typedef BookingSubmit = Future<Appointment> Function(Slot slot, String clientName, String clientPhone);

/// Opens the "pick a day and a time" sheet and returns the resulting booking,
/// or null when the sheet was dismissed.
Future<Appointment?> showBookingSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required SlotLoader loadSlots,
  required BookingSubmit onSubmit,
  List<Specialist> specialists = const [],
  int? specialistId,
  bool moving = false,
  bool askClient = false,
}) {
  return showModalBottomSheet<Appointment>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BookingSheet(
      title: title,
      subtitle: subtitle,
      loadSlots: loadSlots,
      onSubmit: onSubmit,
      specialists: specialists,
      specialistId: specialistId,
      moving: moving,
      askClient: askClient,
    ),
  );
}

class BookingSheet extends StatefulWidget {
  const BookingSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loadSlots,
    required this.onSubmit,
    this.specialists = const [],
    this.specialistId,
    this.moving = false,
    this.askClient = false,
  });

  final String title;
  final String subtitle;
  final SlotLoader loadSlots;
  final BookingSubmit onSubmit;

  /// Who can be chosen; with fewer than two the choice is hidden.
  final List<Specialist> specialists;

  /// Preselected specialist. A booking that is being moved keeps its specialist.
  final int? specialistId;

  /// Moving an existing booking rather than creating one.
  final bool moving;

  /// Ask for the client's name and phone (the owner books by hand).
  final bool askClient;

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late final BookingCubit _cubit;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cubit = BookingCubit(
      loadSlots: widget.loadSlots,
      submit: (slot) => widget.onSubmit(slot, _name.text.trim(), _phone.text.trim()),
      specialistId: widget.specialistId,
      today: context.read<AppClock>().now(),
    )..start();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cubit.close();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final showSpecialists = widget.specialists.length > 1 && !widget.moving;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        );

    return BlocConsumer<BookingCubit, BookingState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.result != null) {
          Navigator.pop(context, state.result);
        } else if (state.error != null) {
          setState(() => _error = state.error);
        }
      },
      builder: (context, state) {
        final slot = state.selected;
        final nameOk = !widget.askClient || _name.text.trim().length >= 2;
        final String buttonText;
        if (slot == null) {
          buttonText = strings.chooseTime;
        } else if (widget.moving) {
          buttonText = strings.moveAt(formatTime(slot.start));
        } else if (widget.askClient) {
          buttonText = strings.bookClientAt(formatTime(slot.start));
        } else {
          buttonText = strings.bookAt(formatTime(slot.start));
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.askClient)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: strings.clientName,
                                    prefixIcon: const Icon(Icons.person_outline),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: strings.phone,
                                    prefixIcon: const Icon(Icons.phone_outlined),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (showSpecialists) ...[
                          label(strings.specialist),
                          SizedBox(
                            height: 44,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              children: [
                                _choice(strings.anySpecialist, state.specialistId == null, () => _pick(null)),
                                for (final s in widget.specialists)
                                  _choice(s.name, state.specialistId == s.id, () => _pick(s.id)),
                              ],
                            ),
                          ),
                        ],
                        label(strings.date),
                        DayStrip(
                          days: state.days,
                          selected: state.day,
                          today: state.days.first,
                          onSelected: (day) {
                            setState(() => _error = null);
                            _cubit.selectDay(day);
                          },
                        ),
                        label('${strings.time} · ${formatDay(state.day, strings.lang)}'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _slots(context, state),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: slot == null || !nameOk || state.submitting ? null : _cubit.submit,
                        child: state.submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(buttonText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pick(int? specialistId) {
    setState(() => _error = null);
    _cubit.selectSpecialist(specialistId);
  }

  Widget _choice(String text, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          showCheckmark: false,
          label: Text(text),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  Widget _slots(BuildContext context, BookingState state) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    if (state.status == LoadStatus.loading || state.status == LoadStatus.initial) {
      return const SizedBox(height: 96, child: Center(child: CircularProgressIndicator()));
    }
    if (state.slots.isEmpty) {
      return SizedBox(
        height: 96,
        child: Center(
          child: Text(
            state.status == LoadStatus.failure ? strings.loadError : strings.noSlots,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final slot in state.slots)
          ChoiceChip(
            showCheckmark: false,
            label: Text(formatTime(slot.start)),
            selected: state.selected == slot,
            onSelected: (_) {
              setState(() => _error = null);
              _cubit.selectSlot(slot);
            },
          ),
      ],
    );
  }
}
