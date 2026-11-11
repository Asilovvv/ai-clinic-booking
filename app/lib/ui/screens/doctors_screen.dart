import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart' show LoadStatus;
import '../../bloc/doctors_bloc.dart';
import '../../bloc/settings_cubit.dart';
import '../../data/models.dart';
import '../theme.dart';

class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key, required this.onBook});

  /// Opens the chat and asks the assistant for this specialist.
  final ValueChanged<Doctor> onBook;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return BlocBuilder<DoctorsBloc, DoctorsState>(
      builder: (context, state) {
        if (state.doctors.isEmpty && state.status == LoadStatus.failure) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error ?? strings.loadError),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<DoctorsBloc>().add(const DoctorsRequested()),
                  child: Text(strings.retry),
                ),
              ],
            ),
          );
        }
        if (state.doctors.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        Widget chip(String? id, String label) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(categoryIcon(id), size: 18),
                showCheckmark: false,
                label: Text(label),
                selected: state.selected == id,
                onSelected: (_) => context.read<DoctorsBloc>().add(DoctorsCategorySelected(id)),
              ),
            );

        final doctors = state.visible;
        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  chip(null, strings.all),
                  for (final category in state.categories) chip(category.id, category.title),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: doctors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _DoctorCard(doctor: doctors[i], onBook: onBook),
              ),
            ),
          ],
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
      color: cardColor(scheme),
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
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Icon(categoryIcon(doctor.category), size: 16, color: scheme.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              doctor.title,
                              style: text.bodyMedium?.copyWith(color: scheme.primary),
                            ),
                          ),
                        ],
                      ),
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
                label: Text(context.strings.bookViaAi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
