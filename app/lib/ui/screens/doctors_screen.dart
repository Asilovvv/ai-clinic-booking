import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart' show LoadStatus;
import '../../bloc/doctors_bloc.dart';
import '../../data/models.dart';

class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key, required this.onBook});

  /// Opens the chat and asks the assistant for this doctor.
  final ValueChanged<Doctor> onBook;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DoctorsBloc, DoctorsState>(
      builder: (context, state) {
        if (state.doctors.isEmpty && state.status == LoadStatus.failure) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error ?? 'Ошибка загрузки'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<DoctorsBloc>().add(const DoctorsRequested()),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        if (state.doctors.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: state.doctors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _DoctorCard(doctor: state.doctors[i], onBook: onBook),
        );
      },
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor, required this.onBook});

  final Doctor doctor;
  final ValueChanged<Doctor> onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    doctor.initials,
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(doctor.title, style: text.bodyMedium?.copyWith(color: scheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(doctor.description, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => onBook(doctor),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Записаться через ИИ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
