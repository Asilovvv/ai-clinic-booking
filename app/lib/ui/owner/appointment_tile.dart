import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/owner_agenda_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// One booking in the owner's schedule, with a menu to change its status.
class OwnerAppointmentTile extends StatelessWidget {
  const OwnerAppointmentTile({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    // What the owner can do next depends on where the booking stands now.
    final actions = switch (appointment.status) {
      'booked' => [
          ('completed', Icons.check_circle_outline, strings.markCompleted),
          ('no_show', Icons.person_off_outlined, strings.markNoShow),
          ('cancelled', Icons.close, strings.cancel),
        ],
      'completed' => [
          ('no_show', Icons.person_off_outlined, strings.markNoShow),
          ('booked', Icons.undo, strings.restore),
        ],
      'no_show' => [
          ('completed', Icons.check_circle_outline, strings.markCompleted),
          ('booked', Icons.undo, strings.restore),
        ],
      _ => [('booked', Icons.undo, strings.restore)],
    };
    final sourceIcon = switch (appointment.source) {
      'chat' => Icons.auto_awesome,
      'owner' => Icons.edit_outlined,
      _ => Icons.apps,
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatTime(appointment.start), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(formatTime(appointment.end), style: muted),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 46,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: statusColor(appointment.status, scheme),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${appointment.serviceName} · ${appointment.specialistName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StatusChip(status: appointment.status),
                    const SizedBox(width: 8),
                    Icon(sourceIcon, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(strings.source(appointment.source), style: muted),
                    const Spacer(),
                    Text(
                      formatMoney(appointment.price, strings),
                      style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (status) => context.read<OwnerAgendaCubit>().setStatus(appointment.id, status),
            itemBuilder: (context) => [
              for (final (status, icon, title) in actions)
                PopupMenuItem(
                  value: status,
                  child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 10), Text(title)]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
