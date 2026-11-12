import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/load_status.dart';
import '../../bloc/owner_agenda_cubit.dart';
import '../../bloc/owner_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/catalog_repository.dart';
import '../../data/models.dart';
import '../../data/owner_repository.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/common.dart';
import 'appointment_tile.dart';

/// The schedule of one day with a strip of days to switch between.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return BlocBuilder<OwnerAgendaCubit, OwnerAgendaState>(
      builder: (context, state) {
        final cubit = context.read<OwnerAgendaCubit>();
        final Widget body;
        if (state.items.isNotEmpty) {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => OwnerAppointmentTile(appointment: state.items[i]),
          );
        } else if (state.status == LoadStatus.failure) {
          body = EmptyState(
            icon: Icons.cloud_off_outlined,
            title: strings.loadError,
            text: state.error,
            action: FilledButton.tonal(onPressed: cubit.load, child: Text(strings.retry)),
          );
        } else if (state.status == LoadStatus.success) {
          body = EmptyState(icon: Icons.event_busy_outlined, title: strings.noBookingsDay);
        } else {
          body = const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            const SizedBox(height: 4),
            DayStrip(days: state.days, selected: state.day, today: state.today, onSelected: cubit.load),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDay(state.day, strings.lang),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('${state.items.where((a) => a.status != 'cancelled').length}'),
                  const SizedBox(width: 4),
                  const Icon(Icons.event_note_outlined, size: 18),
                ],
              ),
            ),
            Expanded(child: RefreshIndicator(onRefresh: cubit.load, child: body)),
          ],
        );
      },
    );
  }
}

/// The owner books a client who called or walked in: pick a service, then a time.
Future<void> startManualBooking(BuildContext context) async {
  final business = context.read<OwnerCubit>().state.business;
  if (business == null) return;
  final catalog = context.read<CatalogRepository>();
  final owner = context.read<OwnerRepository>();
  final agenda = context.read<OwnerAgendaCubit>();
  final strings = context.read<SettingsCubit>().state.strings;
  if (business.services.isEmpty) {
    showMessage(context, strings.noServices);
    return;
  }

  final service = await showModalBottomSheet<Service>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ServicePicker(services: business.services),
  );
  if (service == null || !context.mounted) return;

  final appointment = await showBookingSheet(
    context,
    title: service.name,
    subtitle: '${formatDuration(service.durationMin, strings)} · ${formatMoney(service.price, strings)}',
    specialists: business.specialists.where((s) => service.specialistIds.contains(s.id)).toList(),
    askClient: true,
    loadSlots: (day, specialistId) => catalog.slots(business.id, service.id, day: day, specialistId: specialistId),
    onSubmit: (slot, name, phone) => owner.book(
      serviceId: slot.serviceId,
      specialistId: slot.specialistId,
      start: slot.start,
      clientName: name,
      clientPhone: phone,
    ),
  );
  if (appointment == null || !context.mounted) return;
  await agenda.added(appointment);
  if (!context.mounted) return;
  showMessage(
    context,
    '${strings.bookingCreated}: ${formatDay(appointment.start, strings.lang)}, ${formatTime(appointment.start)}',
  );
}

class _ServicePicker extends StatelessWidget {
  const _ServicePicker({required this.services});

  final List<Service> services;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(strings.chooseService, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final service in services)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(service.name),
                    subtitle: Text(formatDuration(service.durationMin, strings)),
                    trailing: Text(
                      formatMoney(service.price, strings),
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => Navigator.pop(context, service),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
