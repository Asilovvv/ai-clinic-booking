import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart';
import '../../bloc/business_cubit.dart';
import '../../bloc/load_status.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/booking_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/models.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/common.dart';
import 'chat_view.dart';

/// The page of one business: what it offers, who works there and what clients say.
class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key, required this.businessId, this.preview});

  final int businessId;

  /// The catalog's summary, shown while the full card is loading.
  final Business? preview;

  static Route<void> route(Business preview) =>
      MaterialPageRoute(builder: (_) => BusinessScreen(businessId: preview.id, preview: preview));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BusinessCubit(context.read<CatalogRepository>(), businessId, preview: preview)..load(),
      child: const _BusinessView(),
    );
  }
}

class _BusinessView extends StatelessWidget {
  const _BusinessView();

  Future<void> _book(BuildContext context, Business business, Service service) async {
    final catalog = context.read<CatalogRepository>();
    final booking = context.read<BookingRepository>();
    final appointments = context.read<AppointmentsBloc>();
    final strings = context.read<SettingsCubit>().state.strings;
    final appointment = await showBookingSheet(
      context,
      title: service.name,
      subtitle: [
        business.name,
        formatDuration(service.durationMin, strings),
        formatMoney(service.price, strings),
      ].join(' · '),
      specialists: business.specialists.where((s) => service.specialistIds.contains(s.id)).toList(),
      loadSlots: (day, specialistId) =>
          catalog.slots(business.id, service.id, day: day, specialistId: specialistId),
      onSubmit: (slot, _, __) =>
          booking.book(serviceId: slot.serviceId, specialistId: slot.specialistId, start: slot.start),
    );
    if (appointment == null || !context.mounted) return;
    appointments.add(const AppointmentsRequested());
    showMessage(
      context,
      '${strings.bookingDone} ${formatDay(appointment.start, strings.lang)}, ${formatTime(appointment.start)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return BlocBuilder<BusinessCubit, BusinessState>(
      builder: (context, state) {
        final business = state.business;
        if (business == null) {
          return Scaffold(
            appBar: AppBar(),
            body: state.status == LoadStatus.failure
                ? EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: strings.loadError,
                    text: state.error,
                    action: FilledButton.tonal(
                      onPressed: () => context.read<BusinessCubit>().load(),
                      child: Text(strings.retry),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          );
        }
        final loaded = state.status == LoadStatus.success;
        return Scaffold(
          appBar: AppBar(),
          body: RefreshIndicator(
            onRefresh: () => context.read<BusinessCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                _Header(business: business),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    hideMessage(context);
                    Navigator.of(context).push(BusinessChatPage.route(business));
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(strings.askAi),
                ),
                if (!loaded && state.status == LoadStatus.failure)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      children: [
                        Text(state.error ?? strings.loadError, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () => context.read<BusinessCubit>().load(),
                          child: Text(strings.retry),
                        ),
                      ],
                    ),
                  )
                else if (!loaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  SectionTitle(strings.services),
                  if (business.services.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(strings.noServicesYet, style: theme.textTheme.bodyMedium),
                    ),
                  for (final service in business.services)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ServiceCard(service: service, onBook: () => _book(context, business, service)),
                    ),
                  SectionTitle(strings.specialists),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: business.specialists.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _SpecialistCard(specialist: business.specialists[i]),
                    ),
                  ),
                  SectionTitle(
                    strings.reviews,
                    trailing: RatingLabel(rating: business.rating, count: business.reviewsCount),
                  ),
                  if (business.reviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        strings.noReviews,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final review in business.reviews)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReviewCard(review: review),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget info(IconData icon, String value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIconTile(category: business.category, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(business.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            strings.category(business.category, business.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (business.rating != null) ...[
                          const SizedBox(width: 10),
                          RatingLabel(rating: business.rating, count: business.reviewsCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (business.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(business.description, style: text.bodyMedium?.copyWith(height: 1.35)),
          ],
          const SizedBox(height: 4),
          if (business.address.isNotEmpty) info(Icons.place_outlined, business.address),
          info(
            Icons.schedule,
            '${formatWorkingDays(business.workingDays, strings)} · '
            '${formatHours(business.openHour, business.closeHour)}',
          ),
          if (business.phone.isNotEmpty) info(Icons.phone_outlined, business.phone),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onBook});

  final Service service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (service.description.isNotEmpty)
                  Text(service.description, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      formatDuration(service.durationMin, strings),
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatMoney(service.price, strings),
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onBook, child: Text(strings.book)),
        ],
      ),
    );
  }
}

class _SpecialistCard extends StatelessWidget {
  const _SpecialistCard({required this.specialist});

  final Specialist specialist;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              specialist.initials,
              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(specialist.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (specialist.title.isNotEmpty)
                Text(specialist.title, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.author, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Stars(rating: review.rating),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment, style: text.bodyMedium),
          ],
        ],
      ),
    );
  }
}
