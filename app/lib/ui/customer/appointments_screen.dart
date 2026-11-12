import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart';
import '../../bloc/load_status.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/booking_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/models.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/common.dart';

/// The client's bookings: what is ahead and what has passed.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<AppointmentsBloc>()..add(const AppointmentsRequested());
    await bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return BlocConsumer<AppointmentsBloc, AppointmentsState>(
      listenWhen: (prev, curr) => curr.error != null && prev.error != curr.error,
      listener: (context, state) => showMessage(context, state.error!),
      builder: (context, state) {
        if (state.items.isEmpty && (state.status == LoadStatus.loading || state.status == LoadStatus.initial)) {
          return const Center(child: CircularProgressIndicator());
        }
        final upcoming = state.upcoming;
        final history = state.history;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: upcoming.isEmpty ? strings.upcoming : '${strings.upcoming} · ${upcoming.length}'),
                  Tab(text: strings.history),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: () => _refresh(context),
                      child: upcoming.isEmpty
                          ? EmptyState(
                              icon: Icons.event_available,
                              title: strings.noUpcoming,
                              text: strings.noAppointmentsHint,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: upcoming.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _UpcomingCard(appointment: upcoming[i]),
                            ),
                    ),
                    RefreshIndicator(
                      onRefresh: () => _refresh(context),
                      child: history.isEmpty
                          ? EmptyState(icon: Icons.history, title: strings.noHistory)
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: history.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _HistoryCard(appointment: history[i]),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Date, place, service and time: the part shared by both kinds of cards.
class _Summary extends StatelessWidget {
  const _Summary({required this.appointment, this.muted = false});

  final Appointment appointment;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DateBadge(date: appointment.start, muted: muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${appointment.serviceName} · ${appointment.specialistName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 15, color: scheme.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${formatDay(appointment.start, strings.lang)}, ${formatTime(appointment.start)}'
                      ' · ${formatMoney(appointment.price, strings)}',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.appointment});

  final Appointment appointment;

  Future<void> _cancel(BuildContext context) async {
    final bloc = context.read<AppointmentsBloc>();
    final strings = context.read<SettingsCubit>().state.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.cancelQuestion),
        content: Text(
          '${appointment.businessName}\n${appointment.serviceName}\n'
          '${formatDay(appointment.start, strings.lang)}, ${formatTime(appointment.start)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.no)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(strings.cancel)),
        ],
      ),
    );
    if (confirmed == true) bloc.add(AppointmentCancelled(appointment.id));
  }

  Future<void> _move(BuildContext context) async {
    final catalog = context.read<CatalogRepository>();
    final booking = context.read<BookingRepository>();
    final bloc = context.read<AppointmentsBloc>();
    final strings = context.read<SettingsCubit>().state.strings;
    final moved = await showBookingSheet(
      context,
      title: appointment.serviceName,
      subtitle: '${appointment.businessName} · ${appointment.specialistName}',
      specialistId: appointment.specialistId,
      moving: true,
      // The booking's own time counts as free while it is being moved.
      loadSlots: (day, specialistId) => catalog.slots(
        appointment.businessId,
        appointment.serviceId,
        day: day,
        specialistId: specialistId,
        excludeAppointmentId: appointment.id,
      ),
      onSubmit: (slot, _, __) => booking.reschedule(appointment.id, slot.start),
    );
    if (moved == null || !context.mounted) return;
    bloc.add(const AppointmentsRequested());
    showMessage(
      context,
      '${strings.bookingMoved}: ${formatDay(moved.start, strings.lang)}, ${formatTime(moved.start)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          _Summary(appointment: appointment),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _move(context),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(strings.reschedule),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () => _cancel(context),
                icon: const Icon(Icons.close, size: 18),
                label: Text(strings.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.appointment});

  final Appointment appointment;

  Future<void> _rate(BuildContext context) async {
    final bloc = context.read<AppointmentsBloc>();
    final review = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _ReviewDialog(title: appointment.businessName),
    );
    if (review != null) bloc.add(AppointmentReviewed(appointment.id, review.$1, comment: review.$2));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    // A visit that ended without the owner marking it is shown as completed.
    final status = appointment.status == 'booked' ? 'completed' : appointment.status;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _Summary(appointment: appointment, muted: true),
          const SizedBox(height: 8),
          Row(
            children: [
              StatusChip(status: status),
              const Spacer(),
              if (appointment.reviewRating != null)
                Stars(rating: appointment.reviewRating!, size: 20)
              else if (appointment.canReview)
                FilledButton.tonalIcon(
                  onPressed: () => _rate(context),
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: Text(strings.rate),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Five stars and an optional comment; returns (rating, comment).
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.title});

  final String title;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final empty = Theme.of(context).colorScheme.outlineVariant;
    return AlertDialog(
      title: Text(strings.rateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 36,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(Icons.star_rounded, color: i <= _rating ? const Color(0xFFF5A623) : empty),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(hintText: strings.reviewHint),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.close)),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_rating, _comment.text.trim())),
          child: Text(strings.send),
        ),
      ],
    );
  }
}
