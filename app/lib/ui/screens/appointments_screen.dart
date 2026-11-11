import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<AppointmentsBloc>()..add(const AppointmentsRequested());
    await bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppointmentsBloc, AppointmentsState>(
      listenWhen: (prev, curr) => curr.error != null && prev.error != curr.error,
      listener: (context, state) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.error!))),
      builder: (context, state) {
        if (state.items.isEmpty &&
            (state.status == LoadStatus.loading || state.status == LoadStatus.initial)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 80),
                Icon(Icons.event_available, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Записей пока нет',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Напишите ассистенту, что беспокоит и когда удобно — он запишет вас за секунды.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _AppointmentTile(appointment: state.items[i]),
          ),
        );
      },
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});

  final Appointment appointment;

  Future<void> _confirmCancel(BuildContext context) async {
    final bloc = context.read<AppointmentsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: Text(
          '${appointment.doctorName}\n${formatDay(appointment.start)}, ${formatTime(appointment.start)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Отменить')),
        ],
      ),
    );
    if (confirmed == true) bloc.add(AppointmentCancelled(appointment.id));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${appointment.start.day}',
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(formatMonth(appointment.start), style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appointment.doctorName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(appointment.doctorTitle, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${formatDay(appointment.start)}, ${formatTime(appointment.start)}',
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Отменить',
              onPressed: () => _confirmCancel(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
